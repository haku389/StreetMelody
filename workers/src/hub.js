// hub.js — 共通ハブ（life-os-api）へ送る側（WakeFirst・Life_LevelUP の hub.js と同じ形）
//
// 送るのはこの Worker だけ。署名の鍵を端末に置かないための中継（契約 §3）。
// アプリに埋め込んだ合言葉は IPA から抜き出せる。

import { validate, APP_NAME } from "./events.js";

// 契約 §2。**/v1/life-events ではない**
const EVENTS_PATH = "/v1/events";

// 1回の配列に載せる件数の上限。契約 §5 は「1件でも駄目なら全部入らない」。
// 大きく束ねるほど、1行の取り違えで巻き添えになる件数が増える
const MAX_BATCH = 200;

// /v1/events の上限は 4MB。超えるとハブは切り捨ててから解釈するので、
// 大きさが原因なのに「形が違う」という 400 が返る。余裕を持たせる
const MAX_BODY_BYTES = 3 * 1024 * 1024;

export class HubError extends Error {
  constructor(status, body) {
    super(`ハブが ${status} を返した (${EVENTS_PATH}): ${body}`);
    this.name = "HubError";
    this.status = status;
    this.body = body;
  }

  // **行のせいで落ちたか。** 数えて諦めてよいのはこれだけ。
  //
  // 5xx（保存の失敗）と 401（鍵の不一致）は行のせいではない。
  // 台帳に 011 が当たっていない・鍵を入れ間違えた、は**直せば通る**のに、
  // 数えていると5回で諦めて、直したあとも二度と送られない
  get rowsAtFault() {
    return this.status === 400;
  }
}

// enabled — 送り先が設定されているか。無いのは異常ではなく、溜めておくだけ
export function enabled(env) {
  return Boolean(env.LIFE_OS_API_URL && env.LIFE_OS_APP_SECRET);
}

// signBody — 本文に対する HMAC-SHA256。hex 小文字。
//
// **大文字で送ると暗号的に正しくても 401**（契約 §3）。
// 実際に送るバイト列そのものに署名する。組み直してから署名すると、
// 空白や並び順の違いで受け側と一致しなくなる
export async function signBody(secret, body) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// sendLifeEvents — 人生の記録をまとめて送る。**同じ人のぶんだけ**を渡すこと
//
// 返りの語は決め打ちしない（ハブの現物は accepted / updated / unchanged /
// stale / append_only の5つ。増えてもそのまま持ち帰る）
export async function sendLifeEvents(env, events) {
  const total = {};
  if (!events || events.length === 0 || !enabled(env)) return total;

  // 送る前に全件を検査する。1件でも不正なら配列全体が落ちるので、
  // 通信する前に気づいたほうが安い
  const seen = new Set();
  for (const [i, e] of events.entries()) {
    e.app = APP_NAME;
    const err = validate(e);
    if (err) throw new Error(`${i + 1}件目が送れる形でない: ${err}`);
    // **同じ鍵を同じ配列に2度入れない。** どちらが残るかは仕様ではなく
    // ハブの実装の結果で、Go と SQL で逆になっていたことがある
    if (seen.has(e.idempotency_key)) throw new Error(`同じ冪等キーが配列に2度ある: ${e.idempotency_key}`);
    seen.add(e.idempotency_key);
  }

  for (const chunk of split(events)) {
    const res = await postEvents(env, chunk);
    for (const [k, v] of Object.entries(res ?? {})) {
      if (typeof v === "number" && Number.isFinite(v)) total[k] = (total[k] ?? 0) + v;
    }
    // 送った数と返ってきた数が合わないなら、黙って落ちた行がある
    const got = Object.values(res ?? {}).reduce(
      (n, v) => (typeof v === "number" && Number.isFinite(v) ? n + v : n), 0);
    if (got !== chunk.length) {
      throw new Error(`送信 ${chunk.length} 件に対して応答の合計が ${got} 件（黙って落ちた行がある）`);
    }
  }
  return total;
}

async function postEvents(env, events) {
  const body = JSON.stringify(events);
  const res = await fetch(`${env.LIFE_OS_API_URL}${EVENTS_PATH}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Signature": await signBody(env.LIFE_OS_APP_SECRET, body),
    },
    body,
  });
  const text = await res.text();
  // 本文をそのまま持ち帰る。400 には不正な行の番号と hint が、
  // 502 には Postgres の文言が入っていて、台帳の抜けに気づける
  if (!res.ok) throw new HubError(res.status, text);
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`応答を読めない: ${text}`);
  }
}

// split — 件数と本文の大きさで配列を割る
export function split(events) {
  const out = [];
  let cur = [];
  let size = 2; // 角括弧のぶん
  for (const e of events) {
    const n = JSON.stringify(e).length + 1; // 区切りのカンマ
    if (cur.length > 0 && (cur.length >= MAX_BATCH || size + n > MAX_BODY_BYTES)) {
      out.push(cur);
      cur = [];
      size = 2;
    }
    cur.push(e);
    size += n;
  }
  if (cur.length > 0) out.push(cur);
  return out;
}
