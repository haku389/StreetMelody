// index.js — StreetMelody の中継サーバー（Cloudflare Worker）
//
// 端末 → この Worker → 共通ハブ、の中継。契約（life-os-api/docs/contract.md）§3 の形。
// WakeFirst の workers/ と同じ作り。
//
//   端末が言うこと     「いつ・誰と」（相手の user_id・時刻）と、端末の控えの id
//   ここで決めること   自分の user_id（検証したトークンから）・冪等キー・unit・署名
//   DB が決めること    JST の日付・相手のハッシュ・同じ人と同じ日は1件・実在する相手か
//
// 受け口は1つ。POST /v1/encounters にすれちがいを送ると、
//   1. 本人を確かめる（Supabase の /auth/v1/user）
//   2. 本人のトークンで streetmelody.put_encounters を呼ぶ（**ここで「届いた」**）
//   3. 本人の未送信をハブへ流す（応答を待たせない。ctx.waitUntil）
//
// **空の配列は「流すだけ」の合図。** アプリを開いたときに送ると、溜まっている
// ぶんが流れる（ハブの鍵が後から入った日にも、これで流れ始める）。
//
// 返りは端末の控えの id で:
//   { "accepted": ["<id>", …],                      入った（控えから消してよい）
//     "rejected": [{ "id": "<id>", "reason": "…" }] 送り直しても通らない }

import { verifyUser, hasUserID } from "./auth.js";
import { putEncounters } from "./db.js";
import { checkEncounters, sortOut } from "./events.js";
import { enabled as hubEnabled, probeSignature } from "./hub.js";
import { flushMine } from "./flush.js";

// 1件はおよそ120バイト。200件でも30KB に届かない
const MAX_BODY_BYTES = 64 * 1024;

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

export default {
  async fetch(request, env, ctx) {
    const path = new URL(request.url).pathname;

    // 鍵がハブと合っているか（何も積まない）。毎回ハブへ1回送るので、/health とは分ける
    if (request.method === "GET" && path === "/health" && new URL(request.url).searchParams.get("probe") === "hub") {
      return json({ hub_signature: await probeSignature(env) });
    }

    if (request.method === "GET" && path === "/health") {
      // 何が繋がっていないかを見えるようにする。「動いているのに流れていない」を黙って通さない
      return json({
        ok: true,
        hub: hubEnabled(env) ? "設定済み" : "未設定（すれちがいは Supabase に溜まる）",
        supabase: env.SUPABASE_ANON_KEY ? "設定済み" : "未設定",
      });
    }

    if (path !== "/v1/encounters") return json({ error: "見つからない" }, 404);
    if (request.method !== "POST") return json({ error: "POST で送ること" }, 405);

    const who = await verifyUser(request, env);
    if (who.error) return json({ error: who.error }, who.status);

    const text = await request.text();
    if (text.length > MAX_BODY_BYTES) return json({ error: "本文が大きすぎる" }, 413);
    let body;
    try {
      body = JSON.parse(text);
    } catch {
      return json({ error: "JSON として読めない" }, 400);
    }
    if (hasUserID(body)) {
      return json({ error: "本文に user_id を入れないこと（検証したトークンから取る）" }, 400);
    }
    const checked = checkEncounters(body);
    if (checked.error) return json({ error: checked.error }, 400);

    let out = sortOut([], [], checked.rejected);
    if (checked.items.length > 0) {
      let rows;
      try {
        rows = await putEncounters(env, who.token, checked.items);
      } catch (e) {
        // 束の形の問題（DB が呼び出しごと断った）は 400。送り直しても通らない。
        // 1件ずつの問題は DB が rejected で返すので、ここへは来ない
        const status = e.status === 400 ? 400 : 502;
        return json({ error: e.message }, status);
      }
      out = sortOut(checked.items, rows, checked.rejected);
    }

    // 流すのは応答のあと。端末を待たせない
    ctx?.waitUntil?.(
      flushMine(env, who.token, who.userId).then((r) => {
        if (r.error) console.warn(`ハブへ流せなかった: ${r.error}`);
      }),
    );

    return json(out);
  },
};
