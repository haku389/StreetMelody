import { test } from "node:test";
import assert from "node:assert/strict";
import { fromRow, validate, checkEncounters, APP_NAME } from "../src/events.js";

const ME = "7d0b1c2a-1111-4e5d-9c3a-11d6b4f2a0aa";
const row = { other_hash: "0123456789ab", occurred_on: "2026-10-15", occurred_at: "2026-10-14T23:01:00+00:00" };

test("app 名は契約 §1 の streetmelody", () => {
  assert.equal(APP_NAME, "streetmelody");
});

test("鍵は契約 §4 の形。自分の user_id は渡したものを使う", () => {
  const e = fromRow(ME, { ...row, user_id: "someone-else" });
  assert.equal(e.idempotency_key, `streetmelody:encounter_days:${ME}:0123456789ab:2026-10-15`);
  assert.equal(e.user_id, ME);
  assert.equal(validate(e), null);
});

test("ハッシュ・日付・時刻の形が崩れた行は送らない", () => {
  assert.throws(() => fromRow(ME, { ...row, other_hash: "0E9B7A42-3333-4E5D-9C3A-11D6B4F2A003" }));
  assert.throws(() => fromRow(ME, { ...row, occurred_on: "10/15" }));
  assert.throws(() => fromRow(ME, { ...row, occurred_at: "きのう" }));
});

test("台帳の組に無い metric は送らない（track_played はまだ）", () => {
  const e = { ...fromRow(ME, row), metric: "track_played" };
  assert.match(validate(e), /送らない metric/);
});

test("束ごと断るもの・1件ずつ断るもの", () => {
  assert.ok(checkEncounters({}).error);
  assert.ok(checkEncounters({ encounters: Array(201).fill({ id: "x" }) }).error);
  assert.ok(checkEncounters({ encounters: [{ other_user_id: ME }] }).error, "id が無いと、どの1件か返せない");
  const r = checkEncounters({ encounters: [{ id: "a", other_user_id: ME, occurred_at: "x" }] });
  assert.deepEqual(r, { items: [], rejected: [{ id: "a", reason: "occurred_at が時刻でない" }] });
});
