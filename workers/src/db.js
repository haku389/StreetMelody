// db.js — Supabase（PostgREST）を**本人のトークンで**叩く
//
// **service_role を持たない。** あの鍵はプロジェクト全体で RLS を素通りするので、
// 1本漏れるとハブを迂回して public.life_events を直接書ける。
// 本人のトークンで叩けば、触れるのはその人の行だけになる。
// 表そのものには誰も触れず、streetmelody の4つの関数だけが口
// （../supabase/migrations/20261015170000_encounter_outbox.sql）。
//
// 前提: Supabase の Exposed schemas に `streetmelody` が入っていること
// （20261015130000 の注記。足りないと PostgREST が「Invalid schema」を返す）

const SCHEMA = "streetmelody";

export class SupabaseError extends Error {
  constructor(status, body) {
    super(`Supabase が ${status} を返した: ${body}`);
    this.name = "SupabaseError";
    this.status = status;
    this.body = body;
  }
}

async function rpc(env, token, name, args) {
  const res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: env.SUPABASE_ANON_KEY,
      Authorization: token,
      "Content-Type": "application/json",
      // 非 public スキーマの関数を呼ぶときに要る
      "Content-Profile": SCHEMA,
    },
    body: JSON.stringify(args),
  });
  const text = await res.text();
  if (!res.ok) throw new SupabaseError(res.status, text);
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    throw new SupabaseError(res.status, `応答を読めない: ${text}`);
  }
}

// putEncounters — 端末のすれちがいを入れる。日付とハッシュは DB が作る
export function putEncounters(env, token, items) {
  return rpc(env, token, "put_encounters", {
    p_items: items.map((i) => ({ other_user_id: i.other_user_id, occurred_at: i.occurred_at })),
  });
}

export function myUnsentEncounters(env, token, limit = 200) {
  return rpc(env, token, "my_unsent_encounters", { p_limit: limit });
}

// markSent — 届いた印と、**ハブが何と答えたか**を一緒に残す
export function markSent(env, token, items, hubResult) {
  return rpc(env, token, "mark_my_encounters_sent", { p_items: items, p_result: hubResult ?? null });
}

export function markFailed(env, token, items, error) {
  return rpc(env, token, "mark_my_encounters_failed", {
    p_items: items,
    p_error: String(error).slice(0, 500),
  });
}
