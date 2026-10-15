// events.js — 端末のすれちがいと、ハブへ送る形
//
// 端末が言ってよいのは「いつ・誰と」まで（相手の user_id と時刻）。
// 自分の user_id・冪等キー・unit・日付・相手のハッシュは**ここから先で**組む（契約 §3）。

// 契約 §1。鍵の prefix として過去の行に焼き付くので、変えない
// （改名しても据え置く。MelodyLien → StreetMelody のときもこの名前のまま）
export const APP_NAME = "streetmelody";

// 契約 §7 の台帳と同じ組。**ここに無い metric は送らない**（配列全体が落ちる。契約 §5）。
// track_played はまだ送らない —— 冪等キーの形が契約で決まっていない
export const UNITS = Object.freeze({
  encounter_days: "count",
});

// DB の put_encounters と同じ上限
export const MAX_ITEMS = 200;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const HASH = /^[0-9a-f]{12}$/;
const DAY = /^\d{4}-\d{2}-\d{2}$/;

// checkEncounters — 端末から届いた本文を、DB へ渡す前に分ける
//
//   { error }              本文ごと断る（400）
//   { items, rejected }    DB へ渡すもの（端末の id 付き）と、ここで断った1件ずつ
//
// **空の配列は受ける。** 「流すだけ」の合図にする（アプリを開いたとき、
// 溜まっているぶんを流すため。ハブの鍵が後から入った日にも流れ始める）。
// **1件の形が悪くても本文ごとは断らない**（WakeFirst で、1件が後ろを永久に塞いだ）
export function checkEncounters(body) {
  const list = body?.encounters;
  if (!Array.isArray(list)) return { error: "encounters は配列で送ること" };
  if (list.length > MAX_ITEMS) return { error: `1回に送れるのは${MAX_ITEMS}件まで` };

  const items = [];
  const rejected = [];
  for (const [i, e] of list.entries()) {
    if (!e || typeof e !== "object") return { error: `${i + 1}件目が形になっていない` };
    // 端末の控えの id。返りを突き合わせるためだけに使い、DB には入れない
    if (typeof e.id !== "string" || e.id === "") {
      return { error: `${i + 1}件目: id を文字で送ること（どの1件か返せない）` };
    }
    if (typeof e.other_user_id !== "string" || !UUID.test(e.other_user_id)) {
      rejected.push({ id: e.id, reason: "other_user_id が uuid でない" });
    } else if (typeof e.occurred_at !== "string" || Number.isNaN(Date.parse(e.occurred_at))) {
      rejected.push({ id: e.id, reason: "occurred_at が時刻でない" });
    } else {
      items.push({ id: e.id, other_user_id: e.other_user_id, occurred_at: e.occurred_at });
    }
  }
  return { items, rejected };
}

// sortOut — DB の返り（items と同じ順）と、ここで断ったものを端末の id でまとめる
//
//   accepted  stored（入った）と kept（その日はもう入っていた）。端末は控えから消してよい
//   rejected  送り直しても通らない（reason）
//
// DB は届いた順に1件ずつ返す。数が合わないときは**どれも accepted にしない**
// （取り違えて、入っていない1件を消させるより、もう一度送らせるほうが安い）
export function sortOut(items, rows, rejectedHere = []) {
  const out = { accepted: [], rejected: [...rejectedHere] };
  if (!Array.isArray(rows) || rows.length !== items.length) return out;
  for (const [i, r] of rows.entries()) {
    const id = items[i].id;
    // 順番の取り違えを見つける。DB は届いた綴りのまま返す
    if (r?.other_user_id !== items[i].other_user_id) return { accepted: [], rejected: [...rejectedHere] };
    if (r.status === "stored" || r.status === "kept") out.accepted.push(id);
    else if (r.status === "rejected") out.rejected.push({ id, reason: r.reason ?? "DB が断った" });
  }
  return out;
}

// fromRow — DB の未送信の行から、ハブへ送る1件を作る
//
// user_id は**検証したトークンから**取ったもの。行にも本文にも頼らない
export function fromRow(userId, row) {
  if (typeof row?.other_hash !== "string" || !HASH.test(row.other_hash)) {
    throw new Error(`other_hash の形が違う: ${row?.other_hash}`);
  }
  if (typeof row.occurred_on !== "string" || !DAY.test(row.occurred_on)) {
    throw new Error(`occurred_on が日付でない: ${row.occurred_on}`);
  }
  if (typeof row.occurred_at !== "string" || Number.isNaN(Date.parse(row.occurred_at))) {
    throw new Error(`occurred_at が時刻でない: ${row.occurred_at}`);
  }
  return {
    app: APP_NAME,
    user_id: userId,
    // 契約 §4 の形そのもの:
    //   streetmelody:encounter_days:<user_id>:<sha256(相手のuser_id)の先頭12文字>:<日付>
    // 同じ人と同じ日は同じ鍵 ＝ ハブでも1件（「人日」。契約 §8）
    idempotency_key: `${APP_NAME}:encounter_days:${userId}:${row.other_hash}:${row.occurred_on}`,
    metric: "encounter_days",
    unit: UNITS.encounter_days,
    value: 1,
    occurred_at: row.occurred_at,
    occurred_on: row.occurred_on,
  };
}

// validate — ハブの必須項目（契約 §5）。1件でも欠けると配列全体が 400 になる
export function validate(e) {
  for (const k of ["user_id", "idempotency_key", "metric", "unit", "occurred_at", "occurred_on"]) {
    if (typeof e[k] !== "string" || e[k] === "") return `${k} が無い`;
  }
  if (typeof e.value !== "number" || !Number.isFinite(e.value)) return "value が数でない";
  if (!e.idempotency_key.startsWith(`${APP_NAME}:`)) return `鍵が ${APP_NAME}: で始まっていない`;
  if (!Object.hasOwn(UNITS, e.metric)) return `送らない metric (${e.metric})`;
  return null;
}
