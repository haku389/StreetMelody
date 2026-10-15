// flush.js — 溜まったすれちがいを共通ハブへ流す
//
// **本人が送ってきた直後に、本人のぶんだけ流す。** 全員ぶんを一度に流すには
// service_role が要り、その鍵1本でハブを迂回して life_events を書けるように
// なるので持たない（Life_LevelUP と同じ判断）。
//
// 使わなくなった人の行が残る問題は、これでは解けない。アプリを開くたびに端末が
// 送ってくるので、使い続けている人のぶんは次に開いたときに流れる。

import { fromRow, validate } from "./events.js";
import { sendLifeEvents, enabled as hubEnabled, HubError } from "./hub.js";
import { myUnsentEncounters, markSent, markFailed } from "./db.js";

// 印を付けるときの手がかり。表の主キー（相手のハッシュと日付）
const itemOf = (row) => ({ other_hash: row.other_hash, occurred_on: row.occurred_on });

// flushMine — 呼んだ人の未送信を流す。結果は記録のために返す
//
// **例外を外へ投げない。** すれちがいはもう DB に入っている。流せなかったからといって
// 端末に失敗を返すと、端末は同じすれちがいを送り直すだけで、何も良くならない
export async function flushMine(env, token, userId) {
  if (!hubEnabled(env)) return { skipped: "ハブ未設定" };

  let rows;
  try {
    rows = await myUnsentEncounters(env, token);
  } catch (e) {
    return { error: `未送信を引けない: ${e.message}` };
  }
  if (!rows || rows.length === 0) return { sent: 0 };

  // 送れる形にできない行は、送信そのものを巻き添えにしない
  // （配列の1行が駄目なら全部入らない。契約 §5）。
  // ハブの必須項目（validate）もここで見る。sendLifeEvents の中で落ちると
  // 行のせいとは数えられず（下）、同じ1行が毎回束ごと止める
  const events = [];
  const items = [];
  const broken = [];
  for (const row of rows) {
    try {
      const e = fromRow(userId, row);
      const bad = validate(e);
      if (bad) throw new Error(bad);
      events.push(e);
      items.push(itemOf(row));
    } catch (e) {
      broken.push({ item: itemOf(row), reason: e.message });
    }
  }
  if (broken.length > 0) {
    // 数えておく。5回で my_unsent_encounters が返さなくなり、後ろの行が通れる
    await markFailed(env, token, broken.map((b) => b.item), broken[0].reason).catch(() => {});
  }
  if (events.length === 0) return { sent: 0, broken: broken.length };

  let result;
  try {
    result = await sendLifeEvents(env, events);
  } catch (e) {
    // **ハブが「行のせい」と言ったときだけ数える**（HubError の 400）。
    //
    // それ以外はどれも行のせいではない: 5xx や鍵の不一致、名前が引けない・
    // 切れた・LIFE_OS_API_URL に https:// が無い（fetch の TypeError）、応答が
    // 読めない、件数が合わない。直せば通るのに数えていると5回で諦め、
    // 直したあとも二度と送られない
    const rowsAtFault = e instanceof HubError && e.rowsAtFault;
    if (rowsAtFault) await markFailed(env, token, items, e.message).catch(() => {});
    return { error: e.message, counted: rowsAtFault, broken: broken.length };
  }

  // ここから先は**ハブが受け取ったあと**。印を付け損ねても数えない
  // （数えると、届いている行を5回で諦めることになる）。印が無いままなら
  // 次に送ったときにまた流れ、ハブは同じ鍵を冪等に受ける
  try {
    // **返りを一緒に残す。** console だけだと誰も見ない場所で消える
    await markSent(env, token, items, result);
  } catch (e) {
    return { error: `ハブには届いたが、届いた印を付けられない: ${e.message}`,
             counted: false, broken: broken.length, hub: result };
  }

  // 採らなかった件数は、どこを疑うかを名指しする。
  // **どれも失敗ではないので、送信済みの印は付ける**（付けないと永久に送り続ける）
  const warn = [];
  if (result.stale > 0) warn.push(`stale=${result.stale}（recorded_at の作り方を疑う）`);
  if (result.append_only > 0) warn.push(`append_only=${result.append_only}（同じ鍵に違う事実を載せている）`);
  if (warn.length > 0) console.warn(`ハブが採らなかった行がある: ${warn.join(" / ")}`);

  return { sent: items.length, broken: broken.length, hub: result, warn };
}
