// check-deployed.mjs — **配信中のものが、いまのコードか**（Life_LevelUP と同じ）
//
// デプロイは手で行う。直してデプロイし忘れると、git も検査も緑のまま本番だけ古い。
// 時刻ではなく挙動で確かめる: /health が返す項目の顔ぶれは index.js を
// 編集しないと変わらない。**項目を足したらここも足すこと**
const URL_ = process.env.WORKER_URL
  ?? "https://streetmelody-relay.haku-ohitsuji389.workers.dev";

const EXPECTED = ["ok", "hub", "supabase"];

const res = await fetch(`${URL_}/health`);
if (!res.ok) {
  console.error(`配信中の Worker が ${res.status} を返した`);
  process.exit(1);
}
const body = await res.json();
const got = Object.keys(body).sort();
const want = [...EXPECTED].sort();
if (got.join(",") !== want.join(",")) {
  console.error(`配信中のものが、いまのコードと違う（返ってきた: ${got.join(", ")} / いま: ${want.join(", ")}）`);
  process.exit(1);
}
console.log(`配信中の版は、いまのコードと同じ項目を返す（${got.join(", ")}）`);
for (const [k, v] of Object.entries(body)) if (typeof v === "string") console.log(`  ${k}: ${v}`);
