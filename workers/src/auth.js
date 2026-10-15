// auth.js — 誰からの要求かを確かめる（WakeFirst・Life_LevelUP の auth.js と同じ形）
//
// 契約 §3 の中継サーバーの義務: user_id を本文から取らない。
// 端末が言った user_id をそのまま署名して転送すると、鍵を端末に
// 置かなかった意味が次の一段で消える。
//
// **user_id は必ずここで得たものだけを使う。** 本文に user_id が混ざっていたら、
// 無視ではなく 400 で落とす。無視すると、送った側は自分の指定が効いていると
// 思ったまま気づけない。

// verifyUser — Authorization のトークンを Supabase に検証させ、user_id を得る
//
// 自前で JWT を検証しない。公開鍵の取り回しと失効の扱いをこちらに抱えると、
// そこが新しい穴になる
export async function verifyUser(request, env) {
  const auth = request.headers.get("Authorization");
  if (!auth) return { error: "Authorization が無い", status: 401 };

  let res;
  try {
    res = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
      headers: { Authorization: auth, apikey: env.SUPABASE_ANON_KEY },
    });
  } catch {
    // 確かめられなかったのは本人のせいではない。401 にすると端末が
    // トークンを捨ててログインし直させることになる
    return { error: "トークンを確かめられなかった", status: 503 };
  }
  if (res.status >= 500) return { error: "トークンを確かめられなかった", status: 503 };
  if (!res.ok) return { error: "トークンが通らない", status: 401 };

  const user = await res.json().catch(() => null);
  if (!user?.id) return { error: "user_id を取り出せない", status: 401 };

  // 匿名を断る。匿名サインインの有効化はプロジェクト全体の設定なので、
  // 同じプロジェクトにいる他アプリの都合で有効になった瞬間、匿名の user_id で
  // 人生の記録が積まれ始める（名寄せができない。契約 §12⑬）
  if (user.is_anonymous === true) {
    return { error: "匿名アカウントでは記録を積めない", status: 403 };
  }

  return { userId: user.id, token: auth };
}

// hasUserID — 本文のどこかに user_id が混ざっていないか
export function hasUserID(body) {
  const own = (o) => o && typeof o === "object" && Object.prototype.hasOwnProperty.call(o, "user_id");
  if (own(body)) return true;
  return Array.isArray(body?.encounters) && body.encounters.some(own);
}
