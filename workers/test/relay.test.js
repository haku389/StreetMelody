// relay.test.js — 受け口を、fetch を差し替えて端から端まで通す
//
// Supabase とハブの代わりに fetch を差し替える（WakeFirst と同じ作法）。
// 署名は node:crypto で別に計算して突き合わせる —— 同じ関数で作って同じ関数で
// 確かめても、間違いは見つからない

import { test, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { createHmac, createHash } from "node:crypto";
import worker from "../src/index.js";

const ME = "7d0b1c2a-1111-4e5d-9c3a-11d6b4f2a0aa";
// Swift の UUID は大文字で来る
const OTHER = "0E9B7A42-3333-4E5D-9C3A-11D6B4F2A003";
const OTHER_HASH = createHash("sha256").update(OTHER.toLowerCase()).digest("hex").slice(0, 12);

const env = {
  SUPABASE_URL: "https://sb.test",
  SUPABASE_ANON_KEY: "anon-key",
  LIFE_OS_API_URL: "https://hub.test",
  LIFE_OS_APP_SECRET: "s3cret",
};

const encounters = () => [
  { id: "local-1", other_user_id: OTHER, occurred_at: "2026-10-15T08:01:00+09:00" },
  { id: "local-2", other_user_id: OTHER, occurred_at: "2026-10-15T09:30:00+09:00" },
];

const unsent = () => [
  { other_hash: OTHER_HASH, occurred_on: "2026-10-15", occurred_at: "2026-10-14T23:01:00+00:00", attempts: 0 },
];

let calls, routes, original, waits;
const reply = (status, body) =>
  new Response(typeof body === "string" ? body : JSON.stringify(body), { status });

beforeEach(() => {
  calls = [];
  waits = [];
  routes = {
    "/auth/v1/user": () => reply(200, { id: ME }),
    "/rest/v1/rpc/put_encounters": (c) =>
      reply(200, JSON.parse(c.body).p_items.map((x, i) => ({
        other_user_id: x.other_user_id, status: i === 0 ? "stored" : "kept", reason: null }))),
    "/rest/v1/rpc/my_unsent_encounters": () => reply(200, unsent()),
    "/rest/v1/rpc/mark_my_encounters_sent": () => reply(200, "1"),
    "/rest/v1/rpc/mark_my_encounters_failed": () => reply(200, "1"),
    "/v1/events": (c) => reply(200, { accepted: JSON.parse(c.body).length }),
  };
  original = globalThis.fetch;
  globalThis.fetch = async (url, init = {}) => {
    const u = new URL(String(url));
    const call = { path: u.pathname, headers: new Headers(init.headers), body: init.body };
    calls.push(call);
    const route = routes[u.pathname];
    if (!route) throw new Error(`想定していない通信: ${u}`);
    return route(call);
  };
});
afterEach(() => { globalThis.fetch = original; });

const called = (p) => calls.filter((c) => c.path === p);
const ctx = { waitUntil: (p) => waits.push(p) };

async function post(body, { headers = { Authorization: "Bearer tok" }, e = env } = {}) {
  const res = await worker.fetch(new Request("https://relay.test/v1/encounters", {
    method: "POST", headers, body: typeof body === "string" ? body : JSON.stringify(body),
  }), e, ctx);
  await Promise.all(waits);
  return { status: res.status, body: await res.json() };
}

test("入れて、ハブへ流し、届いた印を返りと一緒に付ける", async () => {
  const r = await post({ encounters: encounters() });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body, { accepted: ["local-1", "local-2"], rejected: [] });

  // DB へは本人のトークンで、streetmelody のスキーマを名指しして
  const put = called("/rest/v1/rpc/put_encounters")[0];
  assert.equal(put.headers.get("Authorization"), "Bearer tok");
  assert.equal(put.headers.get("Content-Profile"), "streetmelody");
  // 端末の控えの id は DB へ渡さない
  assert.deepEqual(JSON.parse(put.body).p_items[0], { other_user_id: OTHER, occurred_at: "2026-10-15T08:01:00+09:00" });

  // ハブへ送った本文
  const hub = called("/v1/events")[0];
  const sent = JSON.parse(hub.body);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].app, "streetmelody");
  assert.equal(sent[0].user_id, ME);
  assert.equal(sent[0].idempotency_key, `streetmelody:encounter_days:${ME}:${OTHER_HASH}:2026-10-15`);
  assert.equal(sent[0].metric, "encounter_days");
  assert.equal(sent[0].unit, "count");
  assert.equal(sent[0].value, 1);
  // 相手の user_id は平文で出ていかない
  assert.ok(!hub.body.toLowerCase().includes(OTHER.toLowerCase()));
  // 署名は「送ったバイト列そのもの」の HMAC-SHA256、hex 小文字
  assert.equal(hub.headers.get("X-Signature"),
    createHmac("sha256", env.LIFE_OS_APP_SECRET).update(hub.body).digest("hex"));

  const mark = JSON.parse(called("/rest/v1/rpc/mark_my_encounters_sent")[0].body);
  assert.deepEqual(mark.p_items, [{ other_hash: OTHER_HASH, occurred_on: "2026-10-15" }]);
  assert.deepEqual(mark.p_result, { accepted: 1 });
});

test("本文に user_id があれば、DB に触らずに断る", async () => {
  const r = await post({ encounters: [{ ...encounters()[0], user_id: OTHER }] });
  assert.equal(r.status, 400);
  assert.equal(called("/rest/v1/rpc/put_encounters").length, 0);
});

test("匿名アカウントは断る", async () => {
  routes["/auth/v1/user"] = () => reply(200, { id: ME, is_anonymous: true });
  const r = await post({ encounters: encounters() });
  assert.equal(r.status, 403);
  assert.equal(called("/rest/v1/rpc/put_encounters").length, 0);
});

test("トークンを確かめられなかったら 503（401 にするとログインし直させてしまう）", async () => {
  routes["/auth/v1/user"] = () => reply(502, "down");
  const r = await post({ encounters: encounters() });
  assert.equal(r.status, 503);
});

test("空の配列は「流すだけ」。DB に入れずに、溜まったぶんを流す", async () => {
  const r = await post({ encounters: [] });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body, { accepted: [], rejected: [] });
  assert.equal(called("/rest/v1/rpc/put_encounters").length, 0);
  assert.equal(called("/v1/events").length, 1);
});

test("形の悪い1件だけを断り、残りは入れる", async () => {
  const r = await post({ encounters: [
    { id: "bad", other_user_id: "not-a-uuid", occurred_at: "2026-10-15T08:00:00+09:00" },
    encounters()[0],
  ] });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.accepted, ["local-1"]);
  assert.deepEqual(r.body.rejected, [{ id: "bad", reason: "other_user_id が uuid でない" }]);
  assert.equal(JSON.parse(called("/rest/v1/rpc/put_encounters")[0].body).p_items.length, 1);
});

test("DB が断った1件は、理由つきで返す", async () => {
  routes["/rest/v1/rpc/put_encounters"] = (c) => reply(200, JSON.parse(c.body).p_items.map((x) => ({
    other_user_id: x.other_user_id, status: "rejected", reason: "知らない相手" })));
  const r = await post({ encounters: [encounters()[0]] });
  assert.deepEqual(r.body, { accepted: [], rejected: [{ id: "local-1", reason: "知らない相手" }] });
});

test("DB の返りの順番が合わなければ、どれも accepted にしない", async () => {
  routes["/rest/v1/rpc/put_encounters"] = () => reply(200, [
    { other_user_id: "11111111-1111-4111-8111-111111111111", status: "stored" },
    { other_user_id: OTHER, status: "stored" }]);
  const r = await post({ encounters: encounters() });
  assert.deepEqual(r.body.accepted, []);
});

// 上の検査は「数が同じで順番が違う」だけを見ている。数が足りない形は別に確かめる
// （変異検査で、数の検査を外しても緑だった）
test("DB の返りが送った数より少なければ、どれも accepted にしない", async () => {
  routes["/rest/v1/rpc/put_encounters"] = () => reply(200, [{ other_user_id: OTHER, status: "stored" }]);
  const r = await post({ encounters: encounters() });
  assert.deepEqual(r.body.accepted, []);
});

test("ハブが未設定でも、すれちがいは DB に入る（溜まるだけ）", async () => {
  const r = await post({ encounters: encounters() }, { e: { ...env, LIFE_OS_APP_SECRET: "" } });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.accepted, ["local-1", "local-2"]);
  assert.equal(called("/v1/events").length, 0);
});

test("ハブが 400（行のせい）なら失敗を数える", async () => {
  routes["/v1/events"] = () => reply(400, { error: "bad row" });
  await post({ encounters: [] });
  assert.equal(called("/rest/v1/rpc/mark_my_encounters_failed").length, 1);
  assert.equal(called("/rest/v1/rpc/mark_my_encounters_sent").length, 0);
});

test("ハブが 503・401 なら数えない（直せば通るものを5回で諦めない）", async () => {
  for (const s of [503, 401]) {
    calls.length = 0;
    routes["/v1/events"] = () => reply(s, "x");
    await post({ encounters: [] });
    assert.equal(called("/rest/v1/rpc/mark_my_encounters_failed").length, 0, `status ${s}`);
  }
});

test("知らない道は 404、GET は 405", async () => {
  const a = await worker.fetch(new Request("https://relay.test/v1/facts", { method: "POST" }), env, ctx);
  assert.equal(a.status, 404);
  const b = await worker.fetch(new Request("https://relay.test/v1/encounters"), env, ctx);
  assert.equal(b.status, 405);
});
