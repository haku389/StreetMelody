import { ASSETS, formatNumber, maskForTrack, seedData, getPieceUrl, getPreviewUrl, todayKey, COOLDOWN_MS, OSHI_LIMIT, OSHI_LIMIT_PREMIUM, oshiLimit, PREMIUM_PRICE_LABEL, levelFromExp, SHOP_ITEMS } from "./data.js";
import { createStore, getDailyMissionProgress, artistGroups, titleProgress } from "./store.js";
import { searchTracks as apiSearch } from "./api.js";
import { getAuthUser, signUpEmail, signInEmail, signInOAuth, signInGuest, signOut, onAuthChange } from "./supabase.js";
import { syncOnLogin, syncAfterAction } from "./sync.js";

const store = createStore();

/* ─── 認証（Supabase Auth: メール / Google / Apple / LINE / ゲスト） ─── */
let authEmailFormVisible = false;

function renderAuth(state) {
  const root = document.getElementById("auth-root");
  // undefined = セッション確認中（何も描画しない）、object = ログイン済み
  if (state.authUser !== null) { root.innerHTML = ""; return; }

  root.innerHTML = `
    <div class="auth-backdrop" style="position:fixed;inset:0;z-index:400;background:linear-gradient(160deg,#2a1a4e,#1a1030 60%,#0f0a20);display:flex;align-items:center;justify-content:center;padding:24px;">
      <div class="auth-card" style="width:100%;max-width:360px;">
        <div style="text-align:center;margin-bottom:32px;">
          <div class="auth-art"><img src="./assets/pastel/hero.png" alt="音楽を楽しむ小鳥"></div>
          <h1 style="color:#fff;font-size:24px;font-weight:950;letter-spacing:.04em;">StreetMelody</h1>
          <p style="color:rgba(255,255,255,.55);font-size:12px;margin-top:8px;">すれちがいで音楽がつながる</p>
        </div>

        ${authEmailFormVisible ? `
        <div style="background:rgba(255,255,255,.06);border-radius:18px;padding:16px;margin-bottom:14px;">
          <input id="auth-email" type="email" placeholder="メールアドレス" autocomplete="email"
            style="width:100%;padding:12px 14px;border-radius:12px;border:1px solid rgba(255,255,255,.15);background:rgba(255,255,255,.08);color:#fff;font-size:13px;margin-bottom:8px;box-sizing:border-box;">
          <input id="auth-password" type="password" placeholder="パスワード（6文字以上）" autocomplete="current-password"
            style="width:100%;padding:12px 14px;border-radius:12px;border:1px solid rgba(255,255,255,.15);background:rgba(255,255,255,.08);color:#fff;font-size:13px;margin-bottom:10px;box-sizing:border-box;">
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;">
            <button data-auth-email-login type="button" style="padding:12px;background:#8f6df4;color:#fff;border:none;border-radius:12px;font-size:13px;font-weight:900;cursor:pointer;">ログイン</button>
            <button data-auth-email-signup type="button" style="padding:12px;background:rgba(255,255,255,.12);color:#fff;border:none;border-radius:12px;font-size:13px;font-weight:900;cursor:pointer;">新規登録</button>
          </div>
        </div>` : `
        <button data-auth-email-toggle type="button"
          style="display:block;width:100%;padding:14px;background:#8f6df4;color:#fff;border:none;border-radius:14px;font-size:14px;font-weight:900;cursor:pointer;margin-bottom:10px;">
          ✉️ メールアドレスで続ける
        </button>`}

        <button data-auth-oauth="google" type="button"
          style="display:block;width:100%;padding:14px;background:#fff;color:#333;border:none;border-radius:14px;font-size:14px;font-weight:900;cursor:pointer;margin-bottom:10px;">
          G  Google で続ける
        </button>
        <button data-auth-oauth="apple" type="button"
          style="display:block;width:100%;padding:14px;background:#000;color:#fff;border:1px solid rgba(255,255,255,.2);border-radius:14px;font-size:14px;font-weight:900;cursor:pointer;margin-bottom:10px;">
            Apple で続ける
        </button>
        <button data-auth-oauth="line" type="button"
          style="display:block;width:100%;padding:14px;background:#06c755;color:#fff;border:none;border-radius:14px;font-size:14px;font-weight:900;cursor:pointer;margin-bottom:18px;">
          LINE で続ける
        </button>

        <p id="auth-error" style="color:#ff8a9e;font-size:11px;font-weight:800;text-align:center;min-height:16px;margin-bottom:10px;"></p>

        <button data-auth-guest type="button"
          style="display:block;width:100%;padding:12px;background:none;color:rgba(255,255,255,.6);border:1px dashed rgba(255,255,255,.25);border-radius:14px;font-size:12px;font-weight:800;cursor:pointer;">
          ゲストで始める（フレンド・ランキング等は制限されます）
        </button>
      </div>
    </div>`;
}

function authError(msg) {
  const el = document.getElementById("auth-error");
  if (el) el.textContent = msg;
}

// 同期済みユーザーID（ゲストはnull・同一ユーザーへの再同期を防ぐ）
let syncedUserId = null;

async function refreshAuth() {
  const user = await getAuthUser();
  store.dispatch({ type: "SET_AUTH", user });
  if (user && !user.isGuest) {
    if (user.id !== syncedUserId) {
      syncedUserId = user.id;
      await syncOnLogin(user.id, store);
    }
  } else {
    syncedUserId = null;
  }
}

document.addEventListener("click", async (e) => {
  const t = (sel) => e.target.closest(sel);

  if (t("[data-auth-email-toggle]")) {
    authEmailFormVisible = true;
    renderAuth(store.getState());
    return;
  }
  if (t("[data-auth-email-login]") || t("[data-auth-email-signup]")) {
    const email = document.getElementById("auth-email")?.value.trim();
    const password = document.getElementById("auth-password")?.value;
    if (!email || !password) return authError("メールアドレスとパスワードを入力してください");
    try {
      if (t("[data-auth-email-signup]")) {
        const { needsConfirm } = await signUpEmail(email, password);
        if (needsConfirm) return authError("確認メールを送信しました。メール内のリンクを開いてからログインしてください");
      } else {
        await signInEmail(email, password);
      }
      await refreshAuth();
    } catch (err) {
      authError(err?.message || "認証に失敗しました");
    }
    return;
  }
  if (t("[data-auth-oauth]")) {
    const provider = t("[data-auth-oauth]").dataset.authOauth;
    if (provider === "line") {
      return authError("LINE ログインはカスタム OIDC 連携の設定後に利用できます（本実装で対応）");
    }
    try {
      await signInOAuth(provider); // 成功するとリダイレクト
    } catch (err) {
      authError(`${provider} ログインは Supabase ダッシュボードでプロバイダ設定後に利用できます`);
    }
    return;
  }
  if (t("[data-auth-guest]")) {
    const { local } = await signInGuest();
    await refreshAuth();
    if (local) store.dispatch({ type: "SHOW_TOAST", message: "ローカルゲストで開始しました（データはこの端末のみに保存されます）" });
    return;
  }
  if (t("[data-auth-logout]")) {
    await signOut();
    store.dispatch({ type: "SET_AUTH", user: null });
    return;
  }
  if (t("[data-auth-upgrade]")) {
    // ゲスト → アカウント登録（ログイン画面を再表示。LocalStorage データは維持される）
    await signOut();
    authEmailFormVisible = true;
    store.dispatch({ type: "SET_AUTH", user: null });
    return;
  }
});

// 起動時セッション確認 + OAuth リダイレクト後の反映
refreshAuth();
onAuthChange(() => refreshAuth());

/* ─── YouTube 30秒試聴 ───────────────────────── */
let ytPlayer = null;
let previewTimer = null;
let previewSecondsLeft = 30;
const PREVIEW_SECONDS = 30;
const PREVIEW_DAILY_LIMIT = 3; // 1曲あたり1日3回まで

/** 残り試聴回数（日付が変わればリセット） */
function previewPlaysLeft(state, trackId) {
  const rec = (state.previewPlays || {})[trackId];
  if (!rec || rec.date !== todayKey()) return PREVIEW_DAILY_LIMIT;
  return Math.max(0, PREVIEW_DAILY_LIMIT - rec.count);
}

function loadYTApi() {
  if (window.YT || document.querySelector("#yt-api-script")) return;
  const s = document.createElement("script");
  s.id = "yt-api-script";
  s.src = "https://www.youtube.com/iframe_api";
  document.head.appendChild(s);
}

function openPreview(trackId) {
  const track = seedData.tracks[trackId];
  if (!track?.youtubeVideoId || track.youtubeVideoId.startsWith("official-")) {
    window.alert("この曲はプロトタイプのため試聴できません");
    return;
  }

  // 試聴回数制限チェック（1曲1日3回まで）
  if (previewPlaysLeft(store.getState(), trackId) <= 0) {
    store.dispatch({ type: "SHOW_TOAST", message: "この曲の本日の試聴回数を使い切りました（1日3回まで）" });
    return;
  }
  store.dispatch({ type: "RECORD_PREVIEW_PLAY", trackId, date: todayKey() });

  const modal    = document.getElementById("preview-modal");
  const bar      = document.getElementById("preview-bar");
  const label    = document.getElementById("preview-timer-label");
  const hint     = document.getElementById("preview-hint-label");
  const waveform = document.getElementById("preview-waveform");
  const state    = store.getState();
  const unlocked = state.unlockedTrackIds.includes(trackId);
  const start    = track.chorusStart ?? 0;
  const playsLeft = previewPlaysLeft(state, trackId);

  // 残り回数表示
  const playsLeftLabel = document.getElementById("preview-plays-left");
  if (playsLeftLabel) playsLeftLabel.textContent = `本日あと ${playsLeft} 回試聴できます`;

  document.getElementById("preview-track-name").textContent =
    unlocked ? track.title : (track.titleMasks ? track.titleMasks[0] : "未解放メロディ");
  document.getElementById("preview-artist-name").textContent = track.artistName;
  hint.style.display = "none";
  label.textContent  = `${PREVIEW_SECONDS}`;
  bar.style.transition = "none";
  bar.style.width = "100%";
  waveform.classList.remove("stopped");
  modal.style.display = "flex";

  previewSecondsLeft = PREVIEW_SECONDS;
  clearInterval(previewTimer);

  const startPlayer = () => {
    if (ytPlayer) { ytPlayer.destroy(); ytPlayer = null; }
    // width/height を明示してオフスクリーン要素に埋め込む
    ytPlayer = new window.YT.Player("preview-player", {
      width: 320,
      height: 180,
      videoId: track.youtubeVideoId,
      playerVars: { autoplay: 1, controls: 0, rel: 0, modestbranding: 1, start },
      events: {
        onReady(e) { e.target.setVolume(100); e.target.playVideo(); startCountdown(); },
      },
    });
  };

  const startCountdown = () => {
    requestAnimationFrame(() => {
      bar.style.transition = `width ${PREVIEW_SECONDS}s linear`;
      bar.style.width = "0%";
    });
    previewTimer = setInterval(() => {
      previewSecondsLeft -= 1;
      label.textContent = `${previewSecondsLeft}`;
      if (previewSecondsLeft <= 0) {
        clearInterval(previewTimer);
        ytPlayer?.pauseVideo();
        label.textContent = "完了";
        waveform.classList.add("stopped");
        // 未解放曲: ヒントLv1 自動付与
        const s = store.getState();
        if (!s.unlockedTrackIds.includes(trackId)) {
          if ((s.hintLevels[trackId] || 0) < 1) {
            store.dispatch({ type: "COMPLETE_AD", kind: "hint1" });
          }
          hint.style.display = "block";
        }
      }
    }, 1000);
  };

  if (window.YT?.Player) {
    startPlayer();
  } else {
    loadYTApi();
    window.onYouTubeIframeAPIReady = startPlayer;
  }
}

function closePreview() {
  clearInterval(previewTimer);
  document.getElementById("preview-modal").style.display = "none";
  document.getElementById("preview-waveform").classList.add("stopped");
  if (ytPlayer) { ytPlayer.destroy(); ytPlayer = null; }
  // コンテナをリセットして次回 YT.Player が再生成できるようにする
  document.getElementById("preview-player").innerHTML = "";
}

document.getElementById("preview-close").addEventListener("click", closePreview);
document.getElementById("preview-stop").addEventListener("click", closePreview);
document.getElementById("preview-modal").addEventListener("click", (e) => {
  if (e.target === document.getElementById("preview-modal")) closePreview();
});

/* ─── Selectors ─────────────────────────────── */
function getTrack(id)             { return seedData.tracks[id]; }
function getSelectedTrack(state)  { return getTrack(state.selectedTrackId); }
function getOwned(state, trackId) { return state.collectedPieces[trackId] || []; }
function isUnlocked(state, id)    { return state.unlockedTrackIds.includes(id); }

/** すれちがい相手（NPC）のuserIdから出会い情報を逆引き */
function npcEncounterForUserId(userId) {
  return Object.values(seedData.encounters).find((enc) => enc.fromUserId === userId) || null;
}

function formatDate(timestamp) {
  const d = new Date(timestamp);
  return `${d.getFullYear()}/${String(d.getMonth() + 1).padStart(2, "0")}/${String(d.getDate()).padStart(2, "0")}`;
}

/* ─── Partials ───────────────────────────────── */
function coinPill(amount) {
  return `<div class="coin-pill"><img src="${ASSETS.coin}" alt="">${formatNumber(amount)}</div>`;
}

function artBlock(color = "", src = "") {
  return src
    ? `<div class="art-block ${color}"><img src="${src}" alt=""></div>`
    : `<div class="art-block ${color}"></div>`;
}

function screenHeader(title, sub = "", right = "", backTarget = "home") {
  return `
    <div class="screen-header">
      <button class="icon-button" data-back="${backTarget}" type="button" aria-label="戻る">‹</button>
      <div class="screen-title">
        <h1>${title}</h1>
        ${sub ? `<p>${sub}</p>` : ""}
      </div>
      ${right || `<div class="header-spacer"></div>`}
    </div>`;
}

function pct(cur, tot) { return tot > 0 ? Math.round((cur / tot) * 100) : 0; }

/** カルーセル用パズル所持状況グリッド（メロディ画面メインカード） */
function puzzleGridMini(state, trackId) {
  const track  = getTrack(trackId);
  const owned  = getOwned(state, trackId);
  const COLS = 6, ROWS = 4, total = COLS * ROWS;
  const cells = Array.from({ length: total }, (_, i) => {
    const n  = i + 1;
    const has = owned.includes(n);
    const url = getPieceUrl(trackId, n, has);
    return has
      ? `<div style="line-height:0;position:relative;">
           <img src="${url}" style="width:100%;display:block;" alt="" loading="lazy">
           <div style="position:absolute;inset:0;background:rgba(76,210,150,.22);pointer-events:none;"></div>
         </div>`
      : `<div style="line-height:0;position:relative;background:#3a3060;outline:1px solid rgba(255,255,255,.18);">
           <img src="${url}" style="width:100%;display:block;opacity:0.55;" alt="" loading="lazy">
         </div>`;
  }).join("");
  return `
    <div style="width:100%;height:100%;display:grid;grid-template-columns:repeat(${COLS},1fr);grid-template-rows:repeat(${ROWS},1fr);gap:1px;background:rgba(80,60,140,.5);">
      ${cells}
    </div>
    <div style="position:absolute;bottom:8px;right:10px;background:rgba(0,0,0,.6);color:#fff;font-size:10px;font-weight:900;padding:2px 8px;border-radius:20px;pointer-events:none;">
      ${owned.length} / ${track.pieceCount}
    </div>`;
}

/** クールタイム残り秒数（0以下なら冷却済み） */
function cooldownRemaining(state, encounterId) {
  const t = (state.encounterCooldowns || {})[encounterId];
  if (!t) return 0;
  return Math.max(0, t + COOLDOWN_MS - Date.now());
}
function formatCooldown(ms) {
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  return `${h}時間${m}分`;
}

/** 次に受け取れる出会いへ進むボタン（未確認 or クールタイム明け） */
function nextEncounterButton(state) {
  const order = seedData.encounterOrder;
  const nextId = order.find((id) => cooldownRemaining(state, id) === 0);
  if (!nextId) {
    // 全てクールタイム中 → 最短で再受信できるまでの時間を表示
    const minMs = Math.min(...order.map((id) => cooldownRemaining(state, id)));
    return `
      <div style="text-align:center;padding:16px 0 4px;">
        <p style="font-size:11px;color:var(--muted);font-weight:800;">🎉 今日の出会いを全て確認しました</p>
        <p style="font-size:10px;color:var(--muted);margin-top:4px;">次の出会いまであと ${formatCooldown(minMs)}</p>
      </div>`;
  }
  const enc = seedData.encounters[nextId];
  const nextIdx = order.indexOf(nextId);
  return `
    <button data-next-encounter-id="${nextId}" type="button"
      style="display:flex;align-items:center;justify-content:space-between;width:100%;margin-top:16px;padding:14px 16px;
        background:linear-gradient(135deg,var(--primary),#a78bf8);color:#fff;border:none;border-radius:16px;cursor:pointer;
        font-weight:900;font-size:13px;box-shadow:0 4px 16px rgba(143,109,244,.3);">
      <div style="text-align:left;">
        <p style="font-size:10px;opacity:.8;margin-bottom:3px;">${nextIdx + 1}人目の出会いへ</p>
        <strong>${enc.fromUserName} さん / ${enc.locationLabel}</strong>
      </div>
      <span style="font-size:20px;">›</span>
    </button>`;
}

/** ピース取得後のフレンド申請カード */
function friendPromptCard(state) {
  const pf = state.pendingFriendAdd;
  if (!pf) return "";
  // ゲストはフレンド機能を利用できない（B-2 機能制限）
  if (state.authUser?.isGuest) {
    return `
      <div style="background:rgba(0,0,0,.04);border:1px dashed rgba(0,0,0,.15);border-radius:18px;padding:16px;margin-top:20px;">
        <div style="display:flex;align-items:center;gap:10px;">
          <span style="font-size:20px;">🔒</span>
          <div style="flex:1;">
            <strong style="display:block;font-size:12px;">フレンド機能はゲストでは利用できません</strong>
            <p style="font-size:10px;color:var(--muted);margin-top:2px;">アカウント登録すると ${pf.userName} さんとつながれます</p>
          </div>
          <button data-auth-upgrade type="button"
            style="padding:8px 12px;background:var(--primary);color:#fff;border:none;border-radius:10px;font-size:11px;font-weight:900;cursor:pointer;white-space:nowrap;">登録する</button>
        </div>
      </div>`;
  }
  return `
    <div style="background:linear-gradient(135deg,rgba(143,109,244,.1),rgba(76,175,80,.08));border:1.5px solid rgba(143,109,244,.3);border-radius:18px;padding:16px;margin-top:20px;">
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:12px;">
        <div style="width:40px;height:40px;border-radius:50%;background:var(--primary);display:flex;align-items:center;justify-content:center;color:#fff;font-size:16px;flex:0 0 40px;">🎵</div>
        <div>
          <strong style="display:block;font-size:13px;">${pf.userName} さんとメロディでつながりました</strong>
          <p style="font-size:10px;color:var(--muted);margin-top:2px;">フレンドになって音楽をシェアしませんか？</p>
        </div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;">
        <button data-add-friend-confirm type="button"
          style="padding:10px;background:var(--primary);color:#fff;border:none;border-radius:12px;font-size:12px;font-weight:900;cursor:pointer;">
          フレンドに追加
        </button>
        <button data-dismiss-friend-prompt type="button"
          style="padding:10px;background:rgba(0,0,0,.06);color:var(--muted);border:none;border-radius:12px;font-size:12px;font-weight:900;cursor:pointer;">
          スキップ
        </button>
      </div>
    </div>`;
}

function trackLabel(state, track) {
  if (isUnlocked(state, track.id)) return `${track.artistName} / ${track.title}`;
  return maskForTrack(track, state.hintLevels[track.id] || 0);
}

/* ─── パズル完成演出 ──────────────────────────── */
const PARTICLE_COLORS = ["#f9c74f","#f3722c","#90be6d","#4cc9f0","#f72585","#b5e48c","#a8dadc","#ffb703"];

function renderPuzzleComplete(state) {
  const root = document.getElementById("puzzle-complete-root");
  if (!root) return;

  if (!state.puzzleCompleteTrackId) {
    root.innerHTML = "";
    return;
  }

  const track      = getTrack(state.puzzleCompleteTrackId);
  const previewUrl = getPreviewUrl(state.puzzleCompleteTrackId);
  const owned      = getOwned(state, state.puzzleCompleteTrackId);

  // ランダムパーティクル生成
  const particles = Array.from({ length: 28 }, (_, i) => {
    const color = PARTICLE_COLORS[i % PARTICLE_COLORS.length];
    const size  = 5 + Math.random() * 9;
    const left  = 5 + Math.random() * 90;
    const delay = Math.random() * 0.8;
    const dur   = 1.2 + Math.random() * 1.0;
    const tx    = (Math.random() - 0.5) * 120;
    const ty    = -(60 + Math.random() * 120);
    const shape = Math.random() > 0.4 ? "50%" : "3px"; // 丸 or 四角
    return `<div style="
      position:absolute;bottom:38%;left:${left}%;
      width:${size}px;height:${size}px;
      border-radius:${shape};background:${color};
      animation:pcParticle ${dur}s ease-out ${delay}s both;
      --tx:${tx}px;--ty:${ty}px;pointer-events:none;z-index:1;
    "></div>`;
  }).join("");

  root.innerHTML = `
    <style>
      @keyframes pcBg      { from{opacity:0} to{opacity:1} }
      @keyframes pcIn      { 0%{transform:scale(.55) translateY(40px);opacity:0} 65%{transform:scale(1.04) translateY(-6px)} 100%{transform:scale(1) translateY(0);opacity:1} }
      @keyframes pcFadeUp  { from{opacity:0;transform:translateY(14px)} to{opacity:1;transform:translateY(0)} }
      @keyframes pcParticle{ 0%{opacity:1;transform:translate(0,0) scale(1)} 100%{opacity:0;transform:translate(var(--tx),var(--ty)) scale(0)} }
      @keyframes pcShine   { 0%,100%{opacity:.6;transform:scale(1)} 50%{opacity:1;transform:scale(1.06)} }
    </style>

    <!-- 背景 -->
    <div style="position:fixed;inset:0;z-index:300;background:rgba(96,74,121,.55);animation:pcBg .35s ease both;" aria-hidden="true"></div>

    <!-- パーティクル -->
    <div style="position:fixed;inset:0;z-index:301;pointer-events:none;">${particles}</div>

    <!-- カード -->
    <div style="
      position:fixed;inset:0;z-index:302;
      display:flex;flex-direction:column;align-items:center;justify-content:center;
      padding:24px;
    ">
      <div style="
        width:100%;max-width:340px;
        background:linear-gradient(145deg,#fff9f3,#eee0f2);
        border:1px solid rgba(255,255,255,.14);
        border-radius:28px;padding:22px;
        box-shadow:0 32px 80px rgba(101,72,121,.25);
        animation:pcIn .55s cubic-bezier(.34,1.56,.64,1) .1s both;
      ">
        <!-- 完成画像 -->
        <div style="border-radius:16px;overflow:hidden;margin-bottom:18px;animation:pcShine 2.4s ease-in-out .7s infinite;">
          ${previewUrl
            ? `<img src="${previewUrl}" alt="${track.title}" style="width:100%;display:block;">`
            : `<div style="aspect-ratio:16/9;background:#2a1a4e;"></div>`}
        </div>

        <!-- テキスト -->
        <div style="text-align:center;animation:pcFadeUp .5s ease .5s both;">
          <p style="font-size:24px;margin-bottom:6px;">🎉</p>
          <h2 style="font-size:18px;font-weight:950;color:var(--ink);margin-bottom:4px;">パズル完成！</h2>
          <p style="font-size:13px;font-weight:900;color:var(--ink);margin-bottom:2px;">${track.title}</p>
          <p style="font-size:11px;color:var(--muted);">${track.artistName}</p>
        </div>

        <!-- バッジ -->
        <div style="display:flex;gap:10px;justify-content:center;margin:16px 0;animation:pcFadeUp .5s ease .65s both;">
          <div style="background:rgba(143,109,244,.25);border:1px solid rgba(143,109,244,.4);border-radius:20px;padding:6px 14px;font-size:11px;font-weight:900;color:#86619f;">
            🧩 ${owned.length} / ${track.pieceCount} 完成
          </div>
          <div style="background:rgba(249,199,79,.2);border:1px solid rgba(249,199,79,.4);border-radius:20px;padding:6px 14px;font-size:11px;font-weight:900;color:#977134;">
            🪙 +${track.rewardCoins + 1} コイン
          </div>
          <div style="background:rgba(110,231,183,.18);border:1px solid rgba(110,231,183,.4);border-radius:20px;padding:6px 14px;font-size:11px;font-weight:900;color:#528567;">
            ⭐ +${track.rewardExp} EXP
          </div>
        </div>

        <!-- ボタン -->
        <div style="display:grid;gap:8px;animation:pcFadeUp .5s ease .75s both;">
          <button data-dismiss-puzzle-complete data-after="collection" type="button"
            style="width:100%;padding:13px;border:none;border-radius:16px;background:linear-gradient(#c5a3e5,#a27bc8);color:#fff9f3;font-size:13px;font-weight:900;cursor:pointer;letter-spacing:.04em;">
            コレクションで見る
          </button>
          <button data-dismiss-puzzle-complete type="button"
            style="width:100%;padding:11px;border:1px solid rgba(255,255,255,.15);border-radius:16px;background:transparent;color:var(--muted);font-size:12px;font-weight:800;cursor:pointer;">
            閉じる
          </button>
        </div>
      </div>
    </div>
  `;
}

/* ─── 称号獲得演出 ──────────────────────────── */
function renderTitleCelebration(state) {
  const root = document.getElementById("title-celebration-root");
  if (!root) return;

  const pending = state.pendingTitleCelebrations || [];
  // パズル完成演出と重なる場合は、完成演出を閉じた後に表示する
  if (pending.length === 0 || state.puzzleCompleteTrackId) {
    root.innerHTML = "";
    return;
  }

  const title = seedData.titles.find((t) => t.id === pending[0]);
  if (!title) {
    root.innerHTML = "";
    return;
  }

  root.innerHTML = `
    <style>
      @keyframes tcBg   { from{opacity:0} to{opacity:1} }
      @keyframes tcIn   { 0%{transform:scale(.6) translateY(30px);opacity:0} 65%{transform:scale(1.05) translateY(-5px)} 100%{transform:scale(1) translateY(0);opacity:1} }
      @keyframes tcIcon { 0%,100%{transform:scale(1) rotate(-4deg)} 50%{transform:scale(1.12) rotate(4deg)} }
    </style>
    <div style="position:fixed;inset:0;z-index:310;background:rgba(96,74,121,.55);animation:tcBg .3s ease both;" aria-hidden="true"></div>
    <div style="position:fixed;inset:0;z-index:311;display:flex;align-items:center;justify-content:center;padding:24px;">
      <div style="
        width:100%;max-width:300px;text-align:center;
        background:linear-gradient(145deg,#fff9f3,#f8e6e7);
        border:1px solid rgba(249,199,79,.35);
        border-radius:26px;padding:26px 22px;
        box-shadow:0 28px 70px rgba(101,72,121,.25);
        animation:tcIn .5s cubic-bezier(.34,1.56,.64,1) both;
      ">
        <p style="font-size:11px;font-weight:900;letter-spacing:.18em;color:#977134;margin-bottom:14px;">TITLE UNLOCKED</p>
        <div style="font-size:52px;line-height:1;margin-bottom:14px;display:inline-block;animation:tcIcon 1.8s ease-in-out infinite;">${title.icon}</div>
        <h2 style="font-size:17px;font-weight:950;color:var(--ink);margin-bottom:6px;">称号「${title.name}」を獲得！</h2>
        <p style="font-size:11px;color:var(--muted);margin-bottom:14px;">${title.description}</p>
        <div style="display:flex;gap:8px;justify-content:center;margin-bottom:18px;">
          <span style="background:rgba(249,199,79,.2);border:1px solid rgba(249,199,79,.4);border-radius:16px;padding:5px 12px;font-size:10px;font-weight:900;color:#977134;">🪙 +${title.rewardCoins} コイン</span>
          <span style="background:rgba(110,231,183,.16);border:1px solid rgba(110,231,183,.4);border-radius:16px;padding:5px 12px;font-size:10px;font-weight:900;color:#528567;">⭐ +${title.rewardExp} EXP</span>
        </div>
        <button data-dismiss-title-celebration type="button"
          style="width:100%;padding:12px;border:none;border-radius:15px;background:linear-gradient(90deg,#f9c74f,#f0a04b);color:#3a2400;font-size:13px;font-weight:950;cursor:pointer;letter-spacing:.04em;">
          やったね！
        </button>
        ${pending.length > 1 ? `<p style="font-size:10px;color:var(--muted);margin-top:10px;">ほかに ${pending.length - 1} 件の称号を獲得しています</p>` : ""}
      </div>
    </div>
  `;
}

/* ─── Toast ─────────────────────────────────── */
function renderToast(state) {
  const r = document.querySelector("#toast-root");
  if (r) r.innerHTML = state.toast
    ? `<div class="toast" role="status">${state.toast}</div>` : "";
}

/* ═══════════════════════════════════════════════
   ① ホーム
═══════════════════════════════════════════════ */
function computeCollection(state) {
  const tracks  = Object.values(seedData.tracks);
  const done    = tracks.filter((t) => getOwned(state, t.id).length >= t.pieceCount).length;
  const groups  = artistGroups(state);
  const aDone   = groups.filter((g) => g.completed >= g.tracks.length).length;
  return { done, total: tracks.length, aDone, aTotal: groups.length };
}

function renderHome(state) {
  const { user, mission, dailyPlaylist } = seedData;
  const dailyMission = getDailyMissionProgress(state);
  const heroId    = dailyPlaylist.trackIds[0];
  const heroTrack = getTrack(heroId);
  const heroOwned = heroTrack ? getOwned(state, heroId) : [];
  const heroTotal = heroTrack ? heroTrack.pieceCount : 0;
  const heroRem   = Math.max(heroTotal - heroOwned.length, 0);
  const col       = computeCollection(state);
  const lv        = levelFromExp(state.exp);

  // 届いたメロディ件数（全出会いのうちクールタイムが切れているもの）
  const pendingCount = seedData.encounterOrder.filter(
    (id) => cooldownRemaining(state, id) === 0
  ).length;
  const unlockedCount = state.unlockedTrackIds.length;
  const mysteryCount  = Object.values(seedData.tracks)
    .filter((t) => !t.isUnlocked && getOwned(state, t.id).length > 0 && !isUnlocked(state, t.id))
    .length;

  document.querySelector("#home-screen").innerHTML = `
    <div class="home-header">
      ${avatarWithDeco(state)}
      <div class="home-user">
        <p class="home-overline">YOUR DAILY SOUNDTRACK</p><h1>こんにちは、${user.name}さん <span class="greeting-sun">☀</span></h1>
        <p>Lv.${lv.level}</p>
        <div class="progress"><span style="--progress:${pct(lv.current, lv.next)}%"></span></div>
      </div>
      ${coinPill(state.coins)}
    </div>

    <section class="welcome-hero" aria-label="音楽との新しい出会い">
      <img src="./assets/pastel/hero.png" alt="ヘッドホンをつけ、音符とパズルのピースと一緒に街を歩く小鳥" />
      <div class="welcome-copy"><span class="welcome-eyebrow">A LITTLE MUSIC, A LITTLE MAGIC</span><h2>いつもの道に、<br>新しいメロディ。</h2><p>すれちがうたび、好きな音が増えていく。</p><button class="btn hero-melody-button" data-target="melody" type="button"><span class="hero-note" aria-hidden="true">♫</span><span>届いたメロディを聴く</span><span class="hero-button-arrow" aria-hidden="true">›</span></button></div>
    </section>
    <div class="home-dashboard">
    <!-- 今日のサマリーバナー（即時通知 ON のときだけ表示） -->
    ${pendingCount > 0 && (state.notificationSettings?.immediate !== false) ? `
    <div class="notice-panel" style="cursor:pointer;margin-bottom:14px;" data-target="melody">
      <span style="background:var(--primary);color:#fff;font-size:10px;font-weight:950;border-radius:10px;padding:3px 8px;white-space:nowrap;">NEW</span>
      <div>
        <strong>今日${pendingCount}件のメロディが届いています</strong>
        <p>${mysteryCount > 0 ? `未解放曲が${mysteryCount}曲あります` : "パズル候補を確認しましょう"}</p>
      </div>
      <button class="btn primary btn small" data-target="melody" type="button">確認する</button>
    </div>` : pendingCount > 0 ? `
    <div class="notice-panel" style="cursor:pointer;margin-bottom:14px;opacity:.6;" data-target="melody">
      <span style="font-size:16px;">🔕</span>
      <div>
        <strong>今日${pendingCount}件のメロディが届いています</strong>
        <p>即時通知オフ — まとめ通知でお知らせします</p>
      </div>
      <button class="btn secondary btn small" data-target="melody" type="button">確認する</button>
    </div>` : ""}

    <!-- 今日のメロディ -->
    <div class="hero-panel daily-melody-card" data-target="playlist" style="cursor:pointer;">
      <div class="art-block hero-art ${heroTrack?.color ?? ""}">
        <img src="./assets/pastel/cozy-room.png" alt="レコードのある暖かな部屋">
      </div>
      <div class="hero-content">
        <p class="eyebrow">今日のメロディ</p>
        <h2>${heroTrack ? (isUnlocked(state, heroId) ? heroTrack.title : "未解放メロディ") : "—"}</h2>
        <div class="piece-meter">
          <strong>${heroOwned.length} / ${heroTotal}</strong>
          <span>ピース</span>
        </div>
        <div class="progress"><span style="--progress:${pct(heroOwned.length, heroTotal)}%"></span></div>
        <p>${heroRem > 0 ? `あと${heroRem}ピースで完成！` : "完成！"} · プレイリストを見る ›</p>
      </div>
    </div>

    <!-- コレクション概要 -->
    <div class="section-block collection-overview">
      <div class="section-heading">
        <h2>コレクション</h2>
        <button class="link-button" data-target="collection" type="button">すべて見る</button>
      </div>
      <div class="stat-grid">
        <div class="stat-tile"><span>曲パズル</span><strong>${col.done} / ${col.total}</strong></div>
        <div class="stat-tile"><span>アーティスト</span><strong>${col.aDone} / ${col.aTotal}</strong></div>
        <div class="stat-tile"><span>コイン</span><strong>${formatNumber(state.coins)}</strong></div>
      </div>
    </div>

    <!-- デイリーミッション -->
    <div class="mission-panel">
      <h2>${mission.label}ミッション</h2>
      <strong>${dailyMission.progress} / ${mission.target}</strong>
      <div class="progress"><span style="--progress:${pct(dailyMission.progress, mission.target)}%"></span></div>
      <p style="grid-column:1 / -1;font-size:10px;color:var(--muted);margin-top:2px;">
        ${dailyMission.claimed
          ? `🎉 達成済み！メロディコイン +${mission.rewardCoins} を獲得しました`
          : `ピースを${mission.target}個獲得しよう（達成でメロディコイン +${mission.rewardCoins}）`}
      </p>
    </div>

    <!-- 最近届いた曲 -->
    <div class="section-block recent-melodies">
      <div class="section-heading">
        <h2>最近届いた曲</h2>
        <button class="link-button" data-target="melody" type="button">すべて見る</button>
      </div>
      <div class="song-grid">
        ${state.recentlyAddedTrackIds.slice(0, 3).map(getTrack).filter(Boolean).map((t) => `
          <button class="song-tile" data-open-track="${t.id}" type="button">
            ${artBlock(t.color)}
            <strong>${isUnlocked(state, t.id) ? t.title : "未解放メロディ"}</strong>
            <span>${t.artistName}</span>
          </button>
        `).join("")}
      </div>
    </div>
    </div>
    <button class="discovery-banner" data-target="melody" type="button"><span class="discovery-star" aria-hidden="true">★</span><span><strong>まだ知らない、好きな音に。</strong><small>あなたの世界を広げるメロディを見つけよう。</small></span><span class="discovery-arrow" aria-hidden="true">↗</span></button>
    <p class="home-signoff">Enjoy the little things. Listen to the lovely ones. ♡</p>
  `;
}

/* ═══════════════════════════════════════════════
   ② メロディ（パズル候補カルーセル）
═══════════════════════════════════════════════ */
function renderMelody(state) {
  const encounter  = seedData.encounters[state.activeEncounterId];
  const candidates = encounter.candidates;
  const idx        = state.carouselIndex;
  const total      = candidates.length;
  const candidate  = candidates[idx];
  const track      = getTrack(candidate.trackId);

  const cooldownMs = cooldownRemaining(state, encounter.id);
  const onCooldown = cooldownMs > 0;

  // 出会い切り替え用
  const encounterOrder = seedData.encounterOrder;
  const encIdx  = encounterOrder.indexOf(state.activeEncounterId);
  const encTotal = encounterOrder.length;
  const hasPrevEnc = encIdx > 0;
  const hasNextEnc = encIdx < encTotal - 1;

  document.querySelector("#melody-screen").innerHTML = `
    ${screenHeader("メロディ", "", "", "home")}

    <!-- 出会い進捗バー（順番制・切り替えなし） -->
    <div style="background:rgba(143,109,244,.08);border-radius:14px;padding:10px 14px;margin-bottom:14px;">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
        <p style="font-size:10px;font-weight:900;color:var(--primary);letter-spacing:.04em;">${encIdx + 1} / ${encTotal} 件目の出会い</p>
        <div style="display:flex;gap:4px;">
          ${encounterOrder.map((eid, ei) => {
            const done = !!(state.encounterCooldowns || {})[eid];
            const isNow = eid === state.activeEncounterId;
            return `<div style="width:${isNow ? 18 : 8}px;height:6px;border-radius:3px;background:${done ? "#4caf50" : isNow ? "var(--primary)" : "rgba(143,109,244,.2)"};transition:all .3s;"></div>`;
          }).join("")}
        </div>
      </div>
      <div style="display:flex;align-items:center;gap:10px;">
        <div style="width:36px;height:36px;border-radius:50%;background:var(--primary);display:flex;align-items:center;justify-content:center;color:#fff;font-size:13px;font-weight:900;flex:0 0 36px;">${encIdx + 1}</div>
        <div style="min-width:0;">
          <strong style="display:block;font-size:14px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${encounter.fromUserName} さん</strong>
          <p style="font-size:10px;color:var(--muted);margin-top:1px;">📍 ${encounter.locationLabel} · ${encounter.candidates.length}曲</p>
        </div>
        ${(state.friends || []).some(f => f.userId === encounter.fromUserId)
          ? `<span style="margin-left:auto;font-size:10px;color:var(--primary);font-weight:900;background:rgba(143,109,244,.12);padding:3px 8px;border-radius:8px;">🎵 フレンド</span>`
          : ""}
      </div>
    </div>

    ${onCooldown ? `
    <div style="background:rgba(143,109,244,.12);border:1px solid rgba(143,109,244,.3);border-radius:12px;padding:10px 14px;margin-bottom:12px;display:flex;align-items:center;gap:10px;">
      <span style="font-size:18px;">⏳</span>
      <div>
        <strong style="font-size:11px;display:block;">${encounter.fromUserName} さんとのクールタイム中</strong>
        <p style="font-size:10px;color:var(--muted);margin-top:2px;">あと ${formatCooldown(cooldownMs)} で再度受信できます</p>
      </div>
    </div>` : `
    <p style="text-align:center;color:var(--muted);font-size:11px;font-weight:800;margin-bottom:14px;">
      パズルを選んで「このパズルにする」を押してください
    </p>`}

    <!-- カルーセル（16:9 横向きパズル） -->
    <div class="carousel-16x9-wrap">

      <!-- 前のカード（タップで前へ） -->
      ${idx > 0 ? (() => {
        const pt = getTrack(candidates[idx - 1].trackId);
        const pu = getPreviewUrl(pt.id);
        return `
          <button class="carousel-peek left" data-carousel="prev" type="button" aria-label="前のパズル">
            ${pu
              ? `<img src="${pu}" alt="${pt.artistName}" style="width:100%;height:100%;object-fit:cover;object-position:center;display:block;">`
              : `<div class="art-block ${pt.color}" style="width:100%;height:100%;border-radius:0;"></div>`}
          </button>`;
      })() : `<div class="carousel-peek left empty"></div>`}

      <!-- メインカード -->
      <div class="carousel-16x9-main">
        <div class="carousel-16x9-card" style="position:relative;aspect-ratio:16/9;border-radius:18px;overflow:hidden;background:#1a1a2e;box-shadow:0 16px 40px rgba(60,48,90,.28);">
          ${(() => {
            if (state.carouselViewMode === "mosaic") {
              const previewUrl = getPreviewUrl(track.id);
              return `
                <div style="width:100%;height:100%;position:relative;overflow:hidden;">
                  ${previewUrl
                    ? `<img src="${previewUrl}" alt="" style="width:115%;height:115%;margin:-7.5%;object-fit:cover;filter:blur(12px) brightness(0.78);display:block;">`
                    : `<div style="width:100%;height:100%;background:#2a1a4e;"></div>`}
                  <div style="position:absolute;inset:0;background:rgba(20,10,40,.3);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;">
                    <span style="font-size:22px;">🎵</span>
                    <span style="color:rgba(255,255,255,.7);font-size:10px;font-weight:900;letter-spacing:.08em;">モザイクモード</span>
                  </div>
                </div>`;
            }
            return puzzleGridMini(state, track.id);
          })()}
          <!-- 切り替えボタン -->
          <button data-toggle-carousel-view type="button" style="position:absolute;top:8px;left:8px;background:rgba(0,0,0,.55);color:#fff;border:none;border-radius:20px;font-size:9px;font-weight:900;padding:4px 10px;cursor:pointer;z-index:10;letter-spacing:.04em;">
            ${state.carouselViewMode === "pieces" ? "🎵 フル表示" : "🧩 ピース確認"}
          </button>
        </div>
        <div style="text-align:center;margin-top:12px;">
          <p style="color:var(--muted);font-size:10px;font-weight:800;">${candidate.sourceSlot} · ${candidate.rarity}</p>
          <strong style="display:block;font-size:15px;margin-top:4px;">${track.artistName}</strong>
          <p style="font-size:13px;font-weight:900;letter-spacing:.06em;margin-top:2px;">
            ${isUnlocked(state, track.id) ? track.title
              : (track.titleMasks ? track.titleMasks[state.hintLevels[track.id] || 0] : "?".repeat(track.title.length))}
          </p>
          ${(() => {
            const left = previewPlaysLeft(state, track.id);
            return left > 0
              ? `<button data-preview-track="${track.id}" type="button"
                  style="margin-top:8px;border:none;background:rgba(143,109,244,.12);color:#8f6df4;font-size:10px;font-weight:900;padding:5px 14px;border-radius:20px;cursor:pointer;">
                  ▶ 少し聴く（あと${left}回）
                </button>`
              : `<button type="button" disabled
                  style="margin-top:8px;border:none;background:rgba(0,0,0,.06);color:var(--muted);font-size:10px;font-weight:900;padding:5px 14px;border-radius:20px;cursor:default;">
                  本日の試聴回数を使い切りました
                </button>`;
          })()}
        </div>
      </div>

      <!-- 次のカード（タップで次へ） -->
      ${idx < total - 1 ? (() => {
        const nt = getTrack(candidates[idx + 1].trackId);
        const nu = getPreviewUrl(nt.id);
        return `
          <button class="carousel-peek right" data-carousel="next" type="button" aria-label="次のパズル">
            ${nu
              ? `<img src="${nu}" alt="${nt.artistName}" style="width:100%;height:100%;object-fit:cover;object-position:center;display:block;">`
              : `<div class="art-block ${nt.color}" style="width:100%;height:100%;border-radius:0;"></div>`}
          </button>`;
      })() : `<div class="carousel-peek right empty"></div>`}

    </div>

    <!-- カウンター + 矢印 -->
    <div class="carousel-nav" style="margin-top:12px;">
      <button class="icon-button" data-carousel="prev" type="button" ${idx === 0 ? "disabled" : ""}>‹</button>
      <span style="font-size:12px;font-weight:900;color:var(--muted);">${idx + 1} / ${total}</span>
      <button class="icon-button" data-carousel="next" type="button" ${idx === total - 1 ? "disabled" : ""}>›</button>
    </div>

    <!-- アクション -->
    <div style="display:grid;gap:10px;padding-top:16px;">
      <button class="btn primary" data-select-puzzle type="button">このパズルにする</button>
      <button class="btn secondary" data-target="home" type="button">あとで選ぶ</button>
    </div>

    <!-- 今日の出会い一覧 -->
    <div class="section-block" style="margin-top:24px;">
      <div class="section-heading"><h2>今日の出会い <span style="font-size:10px;color:var(--muted);font-weight:700;">${encTotal}件</span></h2></div>
      <div style="display:grid;gap:8px;margin-top:10px;">
        ${encounterOrder.map((eid, ei) => {
          const enc = seedData.encounters[eid];
          const isActive = eid === state.activeEncounterId;
          const cdMs = cooldownRemaining(state, eid);
          const onCooldown = cdMs > 0; // 直近で交換済み・クールタイム中
          // 未交換 or クールタイム明けで現在より後 → ロック（順番制。クールタイム明けで再受信可なら解除）
          const isLocked = !onCooldown && !isActive && ei > encIdx;
          const clickable = !isLocked;
          const isFriend = (state.friends || []).some(f => f.userId === enc.fromUserId);
          return `
            <div ${clickable ? `data-switch-encounter-id="${eid}"` : ""}
              style="display:flex;align-items:center;gap:12px;padding:10px 12px;border-radius:14px;
                border:${isActive ? "2px solid var(--primary)" : "1px solid rgba(234,223,243,.8)"};
                background:${isActive ? "rgba(143,109,244,.08)" : isLocked ? "rgba(0,0,0,.03)" : "#fff"};
                cursor:${clickable ? "pointer" : "default"};
                opacity:${isLocked ? ".45" : "1"};">
              <div style="width:36px;height:36px;border-radius:50%;
                background:${onCooldown ? "rgba(76,175,80,.15)" : isActive ? "var(--primary)" : "rgba(143,109,244,.15)"};
                display:flex;align-items:center;justify-content:center;flex:0 0 36px;
                font-size:${isLocked ? "14px" : "14px"};font-weight:900;
                color:${onCooldown ? "#4caf50" : isActive ? "#fff" : "var(--primary)"};">
                ${onCooldown ? "✓" : isLocked ? "🔒" : ei + 1}
              </div>
              <div style="min-width:0;flex:1;">
                <strong style="display:block;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                  ${enc.fromUserName}${isFriend ? " 🎵" : ""}
                </strong>
                <p style="font-size:10px;color:var(--muted);margin-top:1px;">📍 ${enc.locationLabel} · ${enc.candidates.length}曲</p>
              </div>
              <div style="text-align:right;flex:0 0 auto;">
                ${onCooldown
                  ? `<span style="font-size:9px;color:#4caf50;font-weight:900;background:rgba(76,175,80,.1);padding:2px 6px;border-radius:6px;">済 · あと${formatCooldown(cdMs)}</span>`
                  : isActive
                    ? `<span style="font-size:9px;color:var(--primary);font-weight:900;">→ 今ここ</span>`
                    : isLocked
                      ? `<span style="font-size:9px;color:var(--muted);">順番待ち</span>`
                      : `<span style="font-size:9px;color:var(--mint);font-weight:900;">受信可</span>`}
              </div>
            </div>`;
        }).join("")}
      </div>
    </div>
  `;
}

/* ═══════════════════════════════════════════════
   ③ ピース選択（6×4グリッド）
═══════════════════════════════════════════════ */
function renderPieceSelect(state) {
  const encounter = seedData.encounters[state.activeEncounterId];
  const candidate = encounter.candidates[state.selectedCandidateIndex];
  if (!candidate) {
    document.querySelector("#piece-select-screen").innerHTML = "";
    return;
  }
  const track     = getTrack(candidate.trackId);
  const owned     = getOwned(state, track.id);
  const available = candidate.availablePieces || [];
  const COLS = 6;
  const ROWS = 4;
  const total = COLS * ROWS;

  document.querySelector("#piece-select-screen").innerHTML = `
    ${screenHeader(
      track.artistName,
      isUnlocked(state, track.id) ? track.title : (track.titleMasks ? track.titleMasks[0] : "未解放メロディ"),
      `<div class="header-spacer"></div>`,
      "melody"
    )}

    <p style="text-align:center;color:var(--muted);font-size:11px;font-weight:800;margin-bottom:12px;">
      取得したいピースを1つ選んでください
    </p>

    <!-- 実ピース画像グリッド -->
    <div style="
      display:grid;
      grid-template-columns:repeat(${COLS},1fr);
      grid-template-rows:repeat(${ROWS},1fr);
      gap:2px;
      border-radius:14px;
      overflow:hidden;
      margin-bottom:14px;
      background:rgba(0,0,0,.15);
      padding:2px;
    ">
      ${Array.from({ length: total }, (_, i) => {
        const n = i + 1;
        const isOwned     = owned.includes(n);
        const isAvailable = available.includes(n) && !isOwned;
        const imgUrl      = getPieceUrl(track.id, n, isOwned);

        if (isOwned) {
          // 所持済み：サムネイルピース（通常表示・クリック不可）
          return `<div style="position:relative;line-height:0;" aria-label="ピース${n} 所持済み">
            <img src="${imgUrl}" style="width:100%;display:block;border-radius:2px;" loading="lazy" alt="">
            <div style="position:absolute;inset:0;background:rgba(76,210,150,.18);border-radius:2px;pointer-events:none;"></div>
            <span style="position:absolute;top:2px;left:3px;font-size:7px;font-weight:900;color:rgba(255,255,255,.8);text-shadow:0 1px 2px rgba(0,0,0,.5);">✓</span>
          </div>`;
        } else if (isAvailable) {
          // 取得可能：lockedピース + 紫ハイライト + クリック可能
          return `<button data-pick-piece="${n}" type="button" style="position:relative;line-height:0;border:0;padding:0;cursor:pointer;background:none;border-radius:2px;" aria-label="ピース${n}を取得">
            <img src="${imgUrl}" style="width:100%;display:block;border-radius:2px;" loading="lazy" alt="">
            <div style="position:absolute;inset:0;background:rgba(143,109,244,.55);border-radius:2px;pointer-events:none;transition:background .15s;"></div>
            <span style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);font-size:8px;font-weight:950;color:#fff;text-shadow:0 1px 3px rgba(0,0,0,.6);">${n}</span>
          </button>`;
        } else {
          // 取得不可：lockedピース（暗め）
          return `<div style="position:relative;line-height:0;opacity:.45;" aria-label="ピース${n} 取得不可">
            <img src="${imgUrl}" style="width:100%;display:block;border-radius:2px;" loading="lazy" alt="">
          </div>`;
        }
      }).join("")}
    </div>

    <!-- 凡例 -->
    <div style="display:flex;gap:14px;justify-content:center;margin-bottom:14px;font-size:10px;font-weight:800;color:var(--muted);">
      <span style="display:flex;align-items:center;gap:4px;"><span style="display:inline-block;width:10px;height:10px;border-radius:2px;background:rgba(143,109,244,.55);"></span>取得可能</span>
      <span style="display:flex;align-items:center;gap:4px;"><span style="display:inline-block;width:10px;height:10px;border-radius:2px;background:rgba(76,210,150,.4);"></span>所持済み</span>
      <span style="display:flex;align-items:center;gap:4px;"><span style="display:inline-block;width:10px;height:10px;border-radius:2px;background:rgba(0,0,0,.15);"></span>取得不可</span>
    </div>

    <button class="btn secondary" style="width:100%;" data-back-to-carousel type="button">‹ パズルを選び直す</button>
  `;
}

/* ═══════════════════════════════════════════════
   ④ 未解放メロディ
═══════════════════════════════════════════════ */
function renderMystery(state) {
  const track = getSelectedTrack(state);
  const hintLevel   = state.hintLevels[track.id] || 0;
  const answerReady = state.answerReadyTrackIds.includes(track.id);
  const showChoices = hintLevel >= 2;

  document.querySelector("#mystery-screen").innerHTML = `
    ${screenHeader("未解放メロディ", "ヒントを使ってこの曲の名前を当てよう！",
      `<button class="text-pill" data-target="melody" type="button">あとで確認</button>`,
      "melody"
    )}

    <div class="mystery-hero">
      <div class="mystery-art">
        <div class="art-block ${track.color}" style="aspect-ratio:1;border-radius:26px;"></div>
        <div class="lock-mark">🔒</div>
        <button class="play-fab" data-preview-track="${track.id}" type="button" aria-label="試聴"
          ${previewPlaysLeft(state, track.id) <= 0 ? `style="opacity:.4;"` : ""}>▶</button>
      </div>
      <h2>${trackLabel(state, track)}</h2>
      <p>未解放メロディ${(() => {
        const left = previewPlaysLeft(state, track.id);
        return left < PREVIEW_DAILY_LIMIT
          ? `（試聴 本日あと${left}回）`
          : "";
      })()}</p>
    </div>

    <div class="section-block">
      <div class="action-stack">
        <button class="btn pink"      data-guess-track="${track.id}" type="button">曲名を当てる</button>
        <button class="btn secondary" data-ad="hint1"  type="button">1つ目のヒントを見る 🎫×1</button>
        <button class="btn secondary" data-ad="hint2"  type="button">2つ目のヒントを見る 🎫×1</button>
        <button class="btn coin"      data-ad="answer" type="button">答えを見る CM×1</button>
      </div>
      ${!state.premium && (state.hintTickets || 0) > 0 ? `
        <p style="font-size:10px;color:var(--primary);font-weight:800;text-align:center;margin-top:8px;">
          🎟️ ヒントチケット ${state.hintTickets}枚所持 — 広告なしで解放されます
        </p>` : ""}
      ${showChoices ? `
        <div class="section-heading" style="margin-top:16px;"><h2>4択ヒント</h2></div>
        <div class="choice-grid">
          ${(track.choices || []).map((c) => `<button type="button">${c}</button>`).join("")}
        </div>` : ""}
    </div>

    <div class="youtube-panel">
      <div class="youtube-icon">▶</div>
      <div>
        <strong>YouTubeで見て確認</strong>
        <p>${answerReady ? "確認すると曲名とアーティスト名を解放します" : "公式MVまたは公式リリックビデオを確認"}</p>
      </div>
      ${answerReady
        ? `<button class="btn primary btn small" data-unlock-track="${track.id}" type="button">確認する</button>`
        : `<button class="btn coin btn small" data-ad="answer" type="button">CM</button>`}
    </div>

    ${friendPromptCard(state)}
    ${nextEncounterButton(state)}
  `;
}

/* ═══════════════════════════════════════════════
   ⑤ 曲パズル（コレクションから遷移）
═══════════════════════════════════════════════ */
function renderPuzzle(state) {
  const track = getSelectedTrack(state);
  const owned = getOwned(state, track.id);
  const liked = state.listenLaterTrackIds.includes(track.id);
  const COLS  = 6;
  const total = track.pieceCount;

  document.querySelector("#puzzle-screen").innerHTML = `
    ${screenHeader(track.title, track.artistName,
      `<button class="icon-button" data-listen-later="${track.id}" type="button">${liked ? "❤️" : "🤍"}</button>`,
      "collection"
    )}

    <div class="puzzle-summary">
      <div class="art-block summary-art ${track.color}">
        <img src="${track.thumbnailUrl}" alt="${track.title}">
      </div>
      <div>
        <p>曲パズル</p>
        <div class="piece-meter compact" style="margin-top:6px;">
          <strong>${owned.length} / ${total}</strong>
          <span>ピース</span>
        </div>
        <div class="progress"><span style="--progress:${pct(owned.length, total)}%"></span></div>
        <p style="margin-top:6px;">あと${Math.max(total - owned.length, 0)}ピースで完成！</p>
      </div>
    </div>

    <div class="section-block">
      <div class="section-heading"><h2>所持ピース</h2></div>
      <!-- 実ピース画像グリッド（6×4） -->
      <div style="
        display:grid;
        grid-template-columns:repeat(${COLS},1fr);
        gap:2px;
        margin-top:10px;
        border-radius:12px;
        overflow:hidden;
        background:rgba(0,0,0,.12);
        padding:2px;
      ">
        ${Array.from({ length: total }, (_, i) => {
          const n   = i + 1;
          const has = owned.includes(n);
          const url = getPieceUrl(track.id, n, has);
          return `<div style="position:relative;line-height:0;${has ? "" : "opacity:.35;"}" aria-label="ピース${n}">
            <img src="${url}" style="width:100%;display:block;border-radius:2px;" loading="lazy" alt="">
            ${has ? `<div style="position:absolute;top:1px;left:2px;font-size:6px;font-weight:900;color:rgba(255,255,255,.7);text-shadow:0 1px 2px rgba(0,0,0,.6);">✓</div>` : ""}
          </div>`;
        }).join("")}
      </div>
      <p style="font-size:10px;color:var(--muted);margin-top:8px;text-align:center;">
        薄いピース＝未所持　✓＝所持済み
      </p>
    </div>

    <div class="section-block">
      <div class="section-heading"><h2>完成報酬</h2></div>
      <div class="reward-grid">
        <div><span>メロディコイン</span><strong>×${track.rewardCoins}</strong></div>
        <div><span>経験値</span><strong>×${track.rewardExp}</strong></div>
      </div>
      <button class="btn primary full" data-target="melody" type="button">ピースを集めにいく</button>
    </div>

    ${friendPromptCard(state)}
    ${nextEncounterButton(state)}
  `;
}

/* ═══════════════════════════════════════════════
   ⑥ コレクション（曲パズル / アーティスト / 推し曲 / 称号）
═══════════════════════════════════════════════ */
function renderCollection(state) {
  const allTracks  = Object.values(seedData.tracks);
  const tab = state.collectionTab || "puzzles";

  const tabBtn = (id, label) =>
    `<button class="collection-tab-btn${tab === id ? " active" : ""}" data-collection-tab="${id}" type="button">${label}</button>`;

  document.querySelector("#collection-screen").innerHTML = `
    <!-- 音楽検索 -->
    <div class="search-bar-wrap">
      <div class="search-bar">
        <span class="search-icon">🔍</span>
        <input id="track-search-input" type="search" placeholder="曲名・アーティストで検索" autocomplete="off" />
      </div>
      <div id="search-results" class="search-results" style="display:none;"></div>
    </div>
` + `
    <div class="home-header" style="margin-bottom:14px;">
      <div class="home-user"><h1>コレクション</h1></div>
    </div>

    <!-- 内部タブ -->
    <div class="collection-tabs">
      ${tabBtn("puzzles",  "曲パズル")}
      ${tabBtn("artists",  "アーティスト")}
      ${tabBtn("oshi",     "推し曲")}
      ${tabBtn("titles",   "称号")}
    </div>

    <!-- 曲パズルタブ -->
    ${tab === "puzzles" ? `
      <div class="section-block">
        <div class="section-heading"><h2>未完成</h2></div>
        <div style="display:grid;gap:10px;margin-top:10px;">
          ${allTracks.filter((t) => getOwned(state, t.id).length < t.pieceCount).map((t) => {
            const owned = getOwned(state, t.id);
            return `
              <button class="song-tile" style="display:flex;align-items:center;gap:12px;width:100%;text-align:left;"
                data-open-track="${t.id}" type="button">
                <div class="art-block ${t.color}" style="width:48px;height:48px;border-radius:14px;flex:0 0 48px;"></div>
                <div style="min-width:0;flex:1;">
                  <strong style="display:block;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                    ${isUnlocked(state, t.id) ? t.title : "未解放メロディ"}
                  </strong>
                  <span style="font-size:10px;color:var(--muted);">${t.artistName}</span>
                  <div class="progress" style="margin-top:4px;">
                    <span style="--progress:${pct(owned.length, t.pieceCount)}%"></span>
                  </div>
                </div>
                <span style="font-size:11px;font-weight:900;color:var(--muted);white-space:nowrap;">
                  ${owned.length}/${t.pieceCount}
                </span>
              </button>`;
          }).join("")}
        </div>
      </div>
      <div class="section-block" style="margin-top:14px;">
        <div class="section-heading"><h2>完成済み</h2></div>
        <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-top:10px;">
          ${allTracks.filter((t) => getOwned(state, t.id).length >= t.pieceCount).map((t) => `
            <button class="song-tile" data-open-track="${t.id}" type="button">
              ${artBlock(t.color)}
              <strong>${isUnlocked(state, t.id) ? t.title : "未解放"}</strong>
              <span style="color:var(--mint);font-size:10px;font-weight:900;">完成！</span>
            </button>`).join("") || `<p style="color:var(--muted);font-size:12px;grid-column:1/-1;">まだ完成したパズルはありません</p>`}
        </div>
      </div>` : ""}

    <!-- アーティストタブ -->
    ${tab === "artists" ? `
      ${artistGroups(state).map((artist) => {
        const tracks = artist.tracks;
        return `
          <div class="section-block" style="margin-top:14px;padding:14px;">
            <div style="display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:12px;">
              <div class="artist-profile" style="padding:0;border:none;background:none;box-shadow:none;backdrop-filter:none;flex:1;min-width:0;">
                <img src="${ASSETS.artist}" alt="${artist.name}">
                <div>
                  <h2>${artist.name}</h2>
                  <p>曲パズル完成数</p>
                  <div class="piece-meter compact" style="margin-top:4px;">
                    <strong>${artist.completed} / ${tracks.length}</strong>
                    <span>完成</span>
                  </div>
                  <div class="progress"><span style="--progress:${pct(artist.completed, tracks.length)}%"></span></div>
                </div>
              </div>
              <button class="link-button" data-open-artist="${artist.id}" type="button"
                style="flex:0 0 auto;margin-left:8px;margin-top:2px;font-size:11px;">詳細 ›</button>
            </div>
            <div class="artist-track-grid" style="margin-top:12px;">
              ${tracks.map((t) => {
                const owned = getOwned(state, t.id);
                const done  = owned.length >= t.pieceCount;
                const sub   = done ? "完成!" : owned.length === 0 ? "未入手" : `あと${t.pieceCount - owned.length}`;
                return `
                  <button class="song-tile" data-open-track="${t.id}" type="button">
                    ${artBlock(t.color)}
                    <strong>${isUnlocked(state, t.id) ? t.title : "未解放"}</strong>
                    <span>${sub}</span>
                  </button>`;
              }).join("")}
            </div>
          </div>`;
      }).join("")}` : ""}

    <!-- 推し曲タブ -->
    ${tab === "oshi" ? (() => {
      const oshiTracks = (state.oshiTrackIds || []).map(getTrack).filter(Boolean);
      if (oshiTracks.length === 0) {
        return `
        <div class="section-block" style="margin-top:14px;padding:16px;">
          <p style="color:var(--muted);font-size:12px;text-align:center;padding:20px 0;">
            推し曲を設定すると、近距離交換でピースが届きます。<br>
            マイページから設定できます（無料${OSHI_LIMIT}曲・プレミアム${OSHI_LIMIT_PREMIUM}曲）
          </p>
          <button class="btn primary full" data-target="mypage" type="button">推し曲を設定する</button>
        </div>`;
      }
      return `
      <div class="section-block" style="margin-top:14px;padding:16px;">
        <div class="section-heading"><h2>推し曲</h2><span style="font-size:10px;color:var(--muted);">${oshiTracks.length} / ${OSHI_LIMIT}曲</span></div>
        <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-top:10px;">
          ${oshiTracks.map((t) => `
            <button class="song-tile" data-open-track="${t.id}" type="button">
              ${artBlock(t.color)}
              <strong>${t.title}</strong>
              <span style="font-size:10px;color:var(--muted);">${t.artistName}</span>
            </button>`).join("")}
        </div>
        <button class="btn secondary full" data-target="mypage" type="button" style="margin-top:14px;">推し曲を編集する</button>
      </div>`;
    })() : ""}

    <!-- 称号タブ -->
    ${tab === "titles" ? (() => {
      const entries = seedData.titles.map((title) => ({ title, p: titleProgress(state, title) }));
      const unlockedCount = entries.filter((e) => e.p.unlocked).length;
      return `
      <div class="section-block" style="margin-top:14px;padding:16px;">
        <div class="section-heading">
          <h2>称号</h2>
          <span style="font-size:10px;color:var(--muted);font-weight:800;">${unlockedCount} / ${entries.length} 獲得</span>
        </div>
        ${entries.map(({ title, p }) => `
          <div style="display:flex;align-items:center;gap:12px;padding:12px 14px;border-radius:16px;margin-top:10px;
            background:${p.unlocked ? "linear-gradient(135deg,rgba(143,109,244,.12),rgba(76,210,150,.10))" : "rgba(0,0,0,.04)"};
            border:1.5px solid ${p.unlocked ? "rgba(143,109,244,.3)" : "transparent"};">
            <span style="font-size:24px;flex:0 0 auto;${p.unlocked ? "" : "filter:grayscale(1);opacity:.45;"}">${title.icon}</span>
            <div style="flex:1;min-width:0;">
              <strong style="display:block;font-size:12px;${p.unlocked ? "" : "color:var(--muted);"}">${title.name}</strong>
              <p style="font-size:10px;color:var(--muted);margin-top:2px;">${title.description}</p>
              <p style="font-size:9px;color:var(--muted);margin-top:2px;">獲得報酬: 🪙${title.rewardCoins} · ⭐${title.rewardExp} EXP</p>
              ${p.unlocked ? "" : `<div class="progress" style="margin-top:5px;"><span style="--progress:${pct(p.current, p.target)}%"></span></div>`}
            </div>
            <span style="font-size:10px;font-weight:900;white-space:nowrap;color:${p.unlocked ? "var(--mint)" : "var(--muted)"};">
              ${p.unlocked ? "獲得済み" : `${p.current} / ${p.target}`}
            </span>
          </div>`).join("")}
      </div>`;
    })() : ""}
  `;
}

/* ═══════════════════════════════════════════════
   ⑦ ランキング
═══════════════════════════════════════════════ */
/** すれちがいNPCの所持ピース数（プロトタイプ用の固定値。友達タブの行にも使用） */
const NPC_PIECES = {
  user_tanaka_yuki:   96,
  user_sato_kenji:    81,
  user_suzuki_aya:    64,
  user_yamada_taro:   47,
  user_nakamura_mika: 28,
};

function renderRanking(state) {
  const tab = state.rankingTab || "today";
  const tabBtn = (id, label) =>
    `<button class="collection-tab-btn${tab === id ? " active" : ""}" data-ranking-tab="${id}" type="button">${label}</button>`;

  // 自分の所持ピース合計（ランキングの指標）
  const myPieces = Object.values(state.collectedPieces).reduce((sum, arr) => sum + arr.length, 0);

  // すれちがいNPC行（出会いデータから生成）
  const npcRows = seedData.encounterOrder.map((eid) => {
    const enc = seedData.encounters[eid];
    return { name: enc.fromUserName, sub: enc.locationLabel, count: NPC_PIECES[enc.fromUserId] ?? 30 };
  });

  // タブごとの参加者プール（NPCは固定値・自分の行のみ実データ）
  const pools = {
    today: npcRows,
    near: [
      ...npcRows,
      { name: "ともき", sub: "渋谷エリア", count: 142 },
      { name: "りんか", sub: "渋谷エリア", count: 121 },
    ],
    all: [
      { name: "ユウキ",   sub: "東京",   count: 512 },
      { name: "さくら",   sub: "大阪",   count: 498 },
      { name: "ハルト",   sub: "福岡",   count: 451 },
      { name: "メイ",     sub: "名古屋", count: 387 },
      { name: "ソウタ",   sub: "札幌",   count: 305 },
      ...npcRows,
    ],
    friend: (state.friends || []).map((f) => ({
      name: f.userName,
      sub: `交換${f.exchangeCount}回`,
      count: NPC_PIECES[f.userId] ?? 30,
    })),
  };

  const hasFriends = tab !== "friend" || pools.friend.length > 0;
  const rows = [...pools[tab], { name: `${seedData.user.name}（あなた）`, sub: "集めたピース", count: myPieces, isMe: true }]
    .sort((a, b) => b.count - a.count)
    .map((r, i) => ({ ...r, rank: i + 1 }));
  const myRank = rows.find((r) => r.isMe)?.rank;

  document.querySelector("#ranking-screen").innerHTML = `
    <div class="home-header" style="margin-bottom:14px;">
      <div class="home-user"><h1>ランキング</h1></div>
    </div>

    <div class="collection-tabs">
      ${tabBtn("today",  "今日")}
      ${tabBtn("near",   "近く")}
      ${tabBtn("friend", "友達")}
      ${tabBtn("all",    "全国")}
    </div>

    ${state.authUser?.isGuest ? `
    <div class="notice-panel" style="margin-top:14px;">
      <span>🔒</span>
      <div>
        <strong>ゲストはランキングに参加できません</strong>
        <p>閲覧のみ可能です。アカウント登録で参加できます</p>
      </div>
      <button class="btn primary btn small" data-auth-upgrade type="button">登録</button>
    </div>` : ""}

    ${hasFriends ? `
    <div class="section-block" style="margin-top:14px;padding:14px;">
      <div class="section-heading">
        <h2>${tab === "today" ? "今日すれちがった人" : tab === "near" ? "近くのエリア" : tab === "friend" ? "フレンド" : "全国"}</h2>
        <span style="font-size:10px;color:var(--muted);">集めたピース数 · あなたは${myRank}位</span>
      </div>
      ${rows.map((r) => `
        <div style="display:flex;align-items:center;gap:12px;padding:10px ${r.isMe ? "8px" : "0"};border-bottom:1px solid rgba(234,223,243,.6);${r.isMe ? "background:rgba(143,109,244,.1);border-radius:12px;" : ""}">
          <span style="font-size:16px;font-weight:950;color:${r.rank <= 3 ? "var(--primary)" : "var(--muted)"};width:24px;text-align:center;">${r.rank}</span>
          <div style="flex:1;min-width:0;">
            <strong style="display:block;font-size:12px;${r.isMe ? "color:var(--primary);" : ""}">${r.name}</strong>
            <p style="font-size:10px;color:var(--muted);">${r.sub}</p>
          </div>
          <span style="font-size:10px;color:${r.isMe ? "var(--primary)" : "var(--muted)"};font-weight:800;">${r.count}枚</span>
        </div>
      `).join("")}
    </div>` : `
    <div class="notice-panel" style="margin-top:14px;">
      <span>🎵</span>
      <div>
        <strong>まだフレンドがいません</strong>
        <p>すれちがいでピースを交換するとフレンド申請できます</p>
      </div>
      <button class="btn primary btn small" data-target="melody" type="button">出会いへ</button>
    </div>`}

    ${tab === "near" ? (state.premium ? `
      <p style="margin-top:14px;font-size:10px;color:var(--muted);text-align:center;">⭐ プレミアム特典でエリアランキングを閲覧できます</p>` : `
      <div class="notice-panel" style="margin-top:14px;">
        <span>📍</span>
        <div>
          <strong>エリアランキング</strong>
          <p>離れたエリアの閲覧はプレミアム機能です</p>
        </div>
        <button class="btn primary btn small" data-target="premium" type="button">詳細</button>
      </div>`) : ""}
  `;
}

/* ═══════════════════════════════════════════════
   プレミアムプラン
═══════════════════════════════════════════════ */
function renderPremium(state) {
  const benefits = [
    { icon: "🚫", title: "広告非表示", desc: "ヒント・答えの解放時に広告視聴が不要になります" },
    { icon: "🎵", title: `推し曲${OSHI_LIMIT_PREMIUM}曲`, desc: `推し曲の設定上限が${OSHI_LIMIT}曲 → ${OSHI_LIMIT_PREMIUM}曲に増えます` },
    { icon: "📍", title: "エリアランキング", desc: "離れたエリアのランキングも閲覧できます" },
  ];

  document.querySelector("#premium-screen").innerHTML = `
    ${screenHeader("プレミアムプラン", state.premium ? "⭐ 加入中" : "もっと音楽でつながる", "", "mypage")}

    <div class="section-block" style="padding:20px;text-align:center;background:linear-gradient(160deg,rgba(249,199,79,.12),rgba(143,109,244,.08));border:1px solid rgba(249,199,79,.35);">
      <div style="font-size:36px;margin-bottom:8px;">⭐</div>
      <h2 style="font-size:16px;font-weight:950;">StreetMelody プレミアム</h2>
      <p style="font-size:13px;font-weight:900;color:var(--primary);margin-top:6px;">${PREMIUM_PRICE_LABEL}</p>
      <p style="font-size:10px;color:var(--muted);margin-top:4px;">プロトタイプのため決済は行われません（模擬加入）</p>
    </div>

    <div class="section-block" style="margin-top:14px;padding:16px;">
      <div class="section-heading"><h2>特典</h2></div>
      <div style="display:grid;gap:12px;margin-top:10px;">
        ${benefits.map((b) => `
          <div style="display:flex;align-items:flex-start;gap:12px;">
            <span style="font-size:20px;flex:0 0 auto;">${b.icon}</span>
            <div>
              <strong style="font-size:12px;">${b.title}</strong>
              <p style="font-size:10px;color:var(--muted);margin-top:2px;">${b.desc}</p>
            </div>
          </div>`).join("")}
      </div>
    </div>

    <div style="margin-top:16px;">
      ${state.premium ? `
        <button class="btn secondary full" data-premium-cancel type="button">解約する</button>
        <p style="font-size:9px;color:var(--muted);text-align:center;margin-top:8px;">解約すると推し曲は無料枠（${OSHI_LIMIT}曲）まで自動調整されます</p>` : `
        <button class="btn primary full" data-premium-join type="button">プレミアムに加入する（模擬決済）</button>`}
    </div>
  `;
}

/* ─── アバター（装備中の装飾つき） ─────────────── */
function avatarWithDeco(state) {
  const deco = SHOP_ITEMS.find((i) => i.id === state.equippedDecoration);
  return `
    <div style="position:relative;flex:0 0 auto;">
      <img class="avatar" src="${ASSETS.mascot}" alt="${seedData.user.name}">
      ${deco ? `<span style="position:absolute;top:-9px;right:-7px;font-size:17px;filter:drop-shadow(0 1px 2px rgba(0,0,0,.25));">${deco.icon}</span>` : ""}
    </div>`;
}

/* ═══════════════════════════════════════════════
   ショップ（メロディコインの使い道）
═══════════════════════════════════════════════ */
function renderShop(state) {
  const items = SHOP_ITEMS.filter((i) => i.type !== "decoration");
  const decos = SHOP_ITEMS.filter((i) => i.type === "decoration");
  const owned = state.ownedDecorations || [];

  const buyButton = (item) => state.coins >= item.price
    ? `<button class="btn coin btn small" data-buy-item="${item.id}" type="button">🪙 ${item.price}</button>`
    : `<button class="btn secondary btn small" type="button" disabled style="opacity:.5;">🪙 ${item.price}</button>`;

  document.querySelector("#shop-screen").innerHTML = `
    ${screenHeader("ショップ", "メロディコインでアイテムを購入できます", "", "mypage")}

    <div class="section-block" style="padding:14px 16px;display:flex;align-items:center;justify-content:space-between;">
      <strong style="font-size:12px;">所持メロディコイン</strong>
      <strong style="font-size:16px;color:var(--primary);">🪙 ${formatNumber(state.coins)}</strong>
    </div>

    <div class="section-block" style="margin-top:14px;padding:16px;">
      <div class="section-heading"><h2>アイテム</h2></div>
      <div style="display:grid;gap:12px;margin-top:10px;">
        ${items.map((item) => `
          <div style="display:flex;align-items:center;gap:12px;">
            <span style="font-size:24px;flex:0 0 32px;text-align:center;">${item.icon}</span>
            <div style="flex:1;min-width:0;">
              <strong style="font-size:12px;">${item.name}${item.type === "ticket" ? ` <span style="font-size:10px;color:var(--muted);">（所持 ${state.hintTickets || 0}枚）</span>` : ""}</strong>
              <p style="font-size:10px;color:var(--muted);margin-top:2px;">${item.desc}</p>
            </div>
            ${buyButton(item)}
          </div>`).join("")}
      </div>
    </div>

    <div class="section-block" style="margin-top:14px;padding:16px;">
      <div class="section-heading"><h2>アバター装飾</h2><span style="font-size:10px;color:var(--muted);">買い切り・付け替え自由</span></div>
      <div style="display:grid;gap:12px;margin-top:10px;">
        ${decos.map((item) => {
          const isOwned = owned.includes(item.id);
          const equipped = state.equippedDecoration === item.id;
          return `
          <div style="display:flex;align-items:center;gap:12px;${equipped ? "background:rgba(143,109,244,.08);border-radius:12px;padding:6px 8px;margin:-6px -8px;" : ""}">
            <span style="font-size:24px;flex:0 0 32px;text-align:center;">${item.icon}</span>
            <div style="flex:1;min-width:0;">
              <strong style="font-size:12px;">${item.name}${equipped ? ` <span style="font-size:9px;color:var(--primary);font-weight:950;">装備中</span>` : ""}</strong>
              <p style="font-size:10px;color:var(--muted);margin-top:2px;">${item.desc}</p>
            </div>
            ${isOwned
              ? `<button class="btn ${equipped ? "secondary" : "primary"} btn small" data-equip-deco="${item.id}" type="button">${equipped ? "外す" : "装備する"}</button>`
              : buyButton(item)}
          </div>`;
        }).join("")}
      </div>
    </div>

    <p style="font-size:10px;color:var(--muted);text-align:center;margin-top:14px;">
      コインはピース獲得・パズル完成・デイリーミッションで集められます
    </p>
  `;
}

/* ─── 設定画面共通: スイッチトグルと設定行 ─────── */
function switchToggle(dataAttr, on) {
  return `
    <button ${dataAttr} type="button" aria-pressed="${on}"
      style="width:44px;height:24px;border-radius:12px;border:none;cursor:pointer;position:relative;flex:0 0 44px;
        background:${on ? "var(--primary)" : "rgba(0,0,0,.18)"};transition:background .15s;">
      <span style="position:absolute;top:3px;left:${on ? "23px" : "3px"};width:18px;height:18px;border-radius:50%;background:#fff;transition:left .15s;box-shadow:0 1px 3px rgba(0,0,0,.25);"></span>
    </button>`;
}

function settingRow(dataAttr, title, desc, on) {
  return `
    <div style="display:flex;align-items:center;gap:12px;padding:12px 0;border-bottom:1px solid rgba(234,223,243,.6);">
      <div style="flex:1;min-width:0;">
        <strong style="font-size:12px;">${title}</strong>
        <p style="font-size:10px;color:var(--muted);margin-top:2px;">${desc}</p>
      </div>
      ${switchToggle(dataAttr, on)}
    </div>`;
}

/* ═══════════════════════════════════════════════
   通知設定
═══════════════════════════════════════════════ */
function renderNotifySettings(state) {
  const ns = state.notificationSettings || { immediate: true, digest: false, digestTime: "20:00", encounter: true, mission: true };
  const row = (key, title, desc, on) => settingRow(`data-toggle-notification="${key}"`, title, desc, on);

  document.querySelector("#notify-settings-screen").innerHTML = `
    ${screenHeader("通知設定", "メロディが届いたときの通知方法", "", "mypage")}

    <div class="section-block" style="padding:4px 16px;">
      ${row("immediate", "即時通知", "メロディが届いたらすぐに通知します", ns.immediate)}
      ${row("digest", "まとめ通知", "1日1回、決まった時間にまとめて通知します", ns.digest)}
      ${ns.digest ? `
        <div style="display:flex;align-items:center;gap:8px;padding:10px 0;border-bottom:1px solid rgba(234,223,243,.6);">
          <span style="font-size:10px;color:var(--muted);font-weight:800;flex:0 0 auto;">通知時間</span>
          ${["09:00", "12:00", "20:00"].map((tm) => `
            <button data-digest-time="${tm}" type="button"
              style="border:1px solid ${ns.digestTime === tm ? "var(--primary)" : "rgba(0,0,0,.12)"};
                background:${ns.digestTime === tm ? "rgba(143,109,244,.12)" : "transparent"};
                color:${ns.digestTime === tm ? "var(--primary)" : "var(--muted)"};
                font-size:11px;font-weight:900;padding:6px 12px;border-radius:16px;cursor:pointer;">${tm}</button>`).join("")}
        </div>` : ""}
      ${row("encounter", "すれちがい通知", "近くで新しい出会いがあったときに通知します", ns.encounter)}
      ${row("mission", "ミッション達成通知", "デイリーミッションを達成したときに通知します", ns.mission)}
    </div>

    <p style="font-size:10px;color:var(--muted);text-align:center;margin-top:14px;">
      プロトタイプのため実際の通知は送信されません（設定は保存されます）
    </p>
  `;
}

/* ═══════════════════════════════════════════════
   バックグラウンド検知設定
═══════════════════════════════════════════════ */
const BG_SCAN_MODES = [
  { id: "powersave",   label: "省電力", desc: "約15分ごとに検知 · バッテリー消費 小" },
  { id: "balanced",    label: "標準",   desc: "約5分ごとに検知 · バッテリー消費 中" },
  { id: "performance", label: "高頻度", desc: "約1分ごとに検知 · バッテリー消費 大" },
];

function renderBgSettings(state) {
  const bg = state.backgroundScan || { enabled: true, mode: "balanced", nightPause: false };

  document.querySelector("#bg-settings-screen").innerHTML = `
    ${screenHeader("バックグラウンド検知", "すれちがいスキャンの省電力設定", "", "mypage")}

    <div class="section-block" style="padding:4px 16px;">
      ${settingRow(`data-toggle-bg="enabled"`, "バックグラウンド検知", "アプリを閉じていても近くの出会いを検知します", bg.enabled)}
      ${bg.enabled ? `
        <div style="padding:12px 0;border-bottom:1px solid rgba(234,223,243,.6);">
          <strong style="font-size:12px;">スキャン頻度</strong>
          <div style="display:grid;gap:8px;margin-top:10px;">
            ${BG_SCAN_MODES.map((m) => `
              <button data-bg-mode="${m.id}" type="button"
                style="display:flex;align-items:center;gap:10px;text-align:left;cursor:pointer;padding:10px 12px;border-radius:14px;
                  border:1.5px solid ${bg.mode === m.id ? "var(--primary)" : "rgba(0,0,0,.1)"};
                  background:${bg.mode === m.id ? "rgba(143,109,244,.1)" : "transparent"};">
                <span style="width:16px;height:16px;border-radius:50%;flex:0 0 16px;
                  border:2px solid ${bg.mode === m.id ? "var(--primary)" : "rgba(0,0,0,.2)"};
                  background:${bg.mode === m.id ? "var(--primary)" : "transparent"};box-shadow:inset 0 0 0 3px #fff;"></span>
                <span style="min-width:0;">
                  <strong style="display:block;font-size:12px;color:${bg.mode === m.id ? "var(--primary)" : "inherit"};">${m.label}</strong>
                  <span style="font-size:10px;color:var(--muted);">${m.desc}</span>
                </span>
              </button>`).join("")}
          </div>
        </div>
        ${settingRow(`data-toggle-bg="nightPause"`, "夜間は検知しない", "22時〜翌6時はスキャンを停止してバッテリーを節約します", bg.nightPause)}` : ""}
    </div>

    <p style="font-size:10px;color:var(--muted);text-align:center;margin-top:14px;">
      プロトタイプのため実際のスキャンは行われません（設定は保存されます）
    </p>
  `;
}

/* ═══════════════════════════════════════════════
   今日のメロディプレイリスト
═══════════════════════════════════════════════ */
function renderPlaylist(state) {
  const pl  = seedData.dailyPlaylist;
  const enc = seedData.encounters[pl.encounterId];
  const subtitle = enc
    ? `${pl.dateLabel}・${enc.locationLabel}で${enc.connectedUsers}人と音楽でつながりました`
    : pl.dateLabel;

  document.querySelector("#playlist-screen").innerHTML = `
    ${screenHeader(pl.title, subtitle, "", "home")}

    <div class="track-list section-block">
      ${pl.trackIds.map(getTrack).filter(Boolean).map((t) => {
        const owned    = getOwned(state, t.id);
        const unlocked = isUnlocked(state, t.id);
        const done     = owned.length >= t.pieceCount;
        return `
        <div class="track-row" style="cursor:pointer;" data-open-track="${t.id}">
          <div class="art-block ${t.color}" style="width:48px;height:48px;border-radius:12px;flex:0 0 48px;"></div>
          <div style="min-width:0;flex:1;">
            <strong>${unlocked ? t.title : "未解放メロディ"}</strong>
            <p>${t.artistName}</p>
            <div class="progress" style="margin-top:4px;"><span style="--progress:${pct(owned.length, t.pieceCount)}%"></span></div>
          </div>
          <div style="text-align:right;flex:0 0 auto;">
            <strong style="display:block;font-size:11px;color:${done ? "var(--mint)" : "inherit"};">${done ? "完成！" : `${owned.length} / ${t.pieceCount}`}</strong>
            <button class="btn secondary btn small" data-preview-track="${t.id}" type="button" style="margin-top:4px;">▶ 試聴</button>
          </div>
        </div>`;
      }).join("")}
    </div>

    <p style="font-size:10px;color:var(--muted);text-align:center;margin-top:14px;">
      すれちがいで出会った曲から、今日のプレイリストが自動で作られます
    </p>
  `;
}

/* ═══════════════════════════════════════════════
   ⑧ マイページ
═══════════════════════════════════════════════ */
function renderMypage(state) {
  const { user } = seedData;
  const lv = levelFromExp(state.exp);

  document.querySelector("#mypage-screen").innerHTML = `
    <div class="home-header" style="margin-bottom:14px;">
      ${avatarWithDeco(state)}
      <div class="home-user">
        <h1>${user.name}${state.premium ? ` <span style="font-size:9px;font-weight:950;color:#b8860b;background:linear-gradient(90deg,rgba(249,199,79,.25),rgba(240,160,75,.25));border:1px solid rgba(249,199,79,.5);border-radius:10px;padding:2px 8px;vertical-align:middle;">⭐ プレミアム</span>` : ""}</h1>
        <p>Lv.${lv.level} · メロディコイン ${formatNumber(state.coins)}</p>
        <div class="progress"><span style="--progress:${pct(lv.current, lv.next)}%"></span></div>
        <p style="font-size:9px;color:var(--muted);margin-top:2px;">次のレベルまで あと${lv.next - lv.current} EXP</p>
      </div>
    </div>

    <!-- アカウント -->
    <div class="section-block" style="padding:16px;margin-bottom:14px;">
      <div class="section-heading"><h2>アカウント</h2></div>
      ${(() => {
        const au = state.authUser;
        if (!au) return `<p style="font-size:11px;color:var(--muted);margin-top:8px;">未ログイン</p>`;
        const providerLabel = { email: "メール", google: "Google", apple: "Apple", line: "LINE", local: "ローカルゲスト" }[au.provider] || au.provider;
        return `
          <div style="display:flex;align-items:center;gap:12px;margin-top:10px;">
            <div style="width:40px;height:40px;border-radius:50%;background:${au.isGuest ? "rgba(0,0,0,.08)" : "var(--primary)"};display:flex;align-items:center;justify-content:center;font-size:16px;color:#fff;">
              ${au.isGuest ? "👤" : "🎵"}
            </div>
            <div style="flex:1;min-width:0;">
              <strong style="display:block;font-size:13px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                ${au.isGuest ? "ゲスト" : (au.email || "ログイン済み")}
              </strong>
              <p style="font-size:10px;color:var(--muted);margin-top:2px;">${providerLabel}${au.isGuest ? " · 機能制限あり" : ""}</p>
            </div>
          </div>
          ${au.isGuest ? `
          <div style="background:rgba(143,109,244,.08);border-radius:12px;padding:10px 12px;margin-top:12px;">
            <p style="font-size:10px;color:var(--muted);">フレンド・ランキング参加・共有・データ引き継ぎにはアカウント登録が必要です</p>
            <button class="btn primary full" data-auth-upgrade type="button" style="margin-top:8px;">アカウント登録する</button>
          </div>` : ""}
          <button class="btn secondary full" data-auth-logout type="button" style="margin-top:10px;">ログアウト</button>`;
      })()}
    </div>

    <!-- フレンド -->
    <div class="section-block" style="padding:16px;margin-bottom:14px;cursor:pointer;" data-target="friends">
      <div class="section-heading">
        <h2>フレンド</h2>
        <span style="font-size:10px;color:var(--muted);">${(state.friends || []).length}人</span>
      </div>
      <p style="font-size:11px;color:var(--muted);margin-top:8px;">音楽でつながった履歴を見る</p>
      <button class="btn secondary full" data-target="friends" type="button" style="margin-top:10px;">フレンド一覧を見る</button>
    </div>

    <!-- 推し曲設定 -->
    <div class="section-block" style="padding:16px;">
      <div class="section-heading"><h2>推し曲設定</h2><span style="font-size:10px;color:var(--muted);">${(state.oshiTrackIds || []).length} / ${oshiLimit(state)}曲</span></div>
      <p style="font-size:11px;color:var(--muted);margin-top:8px;">推し曲を設定すると、すれちがいの相手にあなたの推し曲が届きます（解放済みの曲から選べます）</p>
      ${(() => {
        const total = Object.values(state.oshiDeliveries || {}).reduce((n, c) => n + c, 0);
        return total > 0 ? `<p style="font-size:10px;color:var(--primary);font-weight:800;margin-top:4px;">🎵 これまでに ${total}回 届けました</p>` : "";
      })()}
      ${(state.oshiTrackIds || []).length === 0 ? `
        <p style="color:var(--muted);font-size:11px;text-align:center;padding:14px 0;">まだ推し曲が設定されていません</p>` : `
        <div style="display:grid;gap:8px;margin-top:10px;">
          ${(state.oshiTrackIds || []).map((id) => {
            const t = getTrack(id);
            return `
              <div style="display:flex;align-items:center;gap:10px;padding:8px 10px;border-radius:12px;background:rgba(143,109,244,.06);">
                <div class="art-block ${t.color}" style="width:36px;height:36px;border-radius:10px;flex:0 0 36px;"></div>
                <div style="min-width:0;flex:1;">
                  <strong style="display:block;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">${t.title}</strong>
                  <span style="font-size:10px;color:var(--muted);">${t.artistName}</span>
                </div>
                <button data-toggle-oshi="${id}" type="button"
                  style="border:none;background:rgba(0,0,0,.06);color:var(--muted);width:26px;height:26px;border-radius:50%;font-size:12px;font-weight:900;cursor:pointer;flex:0 0 26px;">✕</button>
              </div>`;
          }).join("")}
        </div>`}
      ${(state.oshiTrackIds || []).length < oshiLimit(state) ? `
        <div style="margin-top:14px;">
          <p style="font-size:10px;color:var(--muted);font-weight:800;margin-bottom:6px;">解放済みの曲から選択</p>
          <div style="display:flex;flex-wrap:wrap;gap:8px;">
            ${state.unlockedTrackIds.filter((id) => !(state.oshiTrackIds || []).includes(id)).map((id) => {
              const t = getTrack(id);
              return `<button data-toggle-oshi="${id}" type="button"
                style="border:1px solid rgba(143,109,244,.3);background:rgba(143,109,244,.06);color:var(--primary);
                  font-size:11px;font-weight:900;padding:6px 12px;border-radius:20px;cursor:pointer;">+ ${t.title}</button>`;
            }).join("") || `<p style="color:var(--muted);font-size:11px;">解放済みの曲がありません</p>`}
          </div>
        </div>` : state.premium ? `
        <p style="font-size:10px;color:var(--muted);margin-top:10px;">上限（${OSHI_LIMIT_PREMIUM}曲）に達しています</p>` : `
        <p style="font-size:10px;color:var(--muted);margin-top:10px;">上限（${OSHI_LIMIT}曲）に達しています。<button data-target="premium" type="button" style="border:none;background:none;color:var(--primary);font-size:10px;font-weight:900;cursor:pointer;padding:0;text-decoration:underline;">プレミアム</button>で${OSHI_LIMIT_PREMIUM}曲まで設定可能</p>`}
    </div>

    <!-- 音楽サービス連携 -->
    <div class="section-block" style="margin-top:14px;padding:16px;">
      <div class="section-heading"><h2>音楽サービス連携</h2></div>
      <div style="display:grid;gap:10px;margin-top:10px;">
        ${[
          { id: "spotify",      name: "Spotify",       icon: "🎵" },
          { id: "appleMusic",   name: "Apple Music",   icon: "🎵" },
          { id: "youtubeMusic", name: "YouTube Music", icon: "▶" },
        ].map((sv) => {
          const connected = (state.linkedServices || {})[sv.id];
          return `
          <div style="display:flex;align-items:center;justify-content:space-between;padding:10px 0;border-bottom:1px solid rgba(234,223,243,.6);">
            <span style="font-size:13px;font-weight:900;">${sv.icon} ${sv.name}${connected ? ` <span style="font-size:9px;color:var(--mint);font-weight:950;">✓ 連携中</span>` : ""}</span>
            <button class="btn ${connected ? "secondary" : "primary"} btn small" data-link-service="${sv.id}" type="button">
              ${connected ? "解除" : "連携する"}
            </button>
          </div>`;
        }).join("")}
      </div>
    </div>

    <!-- 設定メニュー -->
    <div class="section-block" style="margin-top:14px;padding:0;">
      ${[
        { label: "通知設定", sub: "即時通知・まとめ通知の設定", target: "notify-settings" },
        { label: "バックグラウンド検知", sub: (state.backgroundScan || {}).enabled === false ? "オフ" : `オン · ${(BG_SCAN_MODES.find((m) => m.id === (state.backgroundScan || {}).mode) || BG_SCAN_MODES[1]).label}スキャン`, target: "bg-settings" },
        { label: "プレミアムプラン", sub: state.premium ? "⭐ 加入中 · 広告非表示・推し曲5曲・エリアランキング" : "広告非表示・推し曲5曲・エリアランキング", target: "premium" },
        { label: "ショップ", sub: `メロディコイン · アバター装飾${state.hintTickets ? ` · 🎟️×${state.hintTickets}` : ""}`, target: "shop" },
        { label: "ヘルプ", sub: "" },
        { label: "利用規約 / プライバシーポリシー", sub: "" },
      ].map((m) => `
        <div ${m.target ? `data-target="${m.target}"` : ""} style="display:flex;align-items:center;justify-content:space-between;padding:14px 16px;border-bottom:1px solid rgba(234,223,243,.6);cursor:pointer;">
          <div>
            <strong style="font-size:13px;">${m.label}</strong>
            ${m.sub ? `<p style="font-size:10px;color:var(--muted);margin-top:2px;">${m.sub}</p>` : ""}
          </div>
          <span style="color:var(--muted);font-size:16px;">›</span>
        </div>`).join("")}
    </div>
  `;
}

/* ═══════════════════════════════════════════════
   ⑨ フレンド一覧
═══════════════════════════════════════════════ */
function renderFriends(state) {
  const friends = [...(state.friends || [])].sort((a, b) => b.addedAt - a.addedAt);

  document.querySelector("#friends-screen").innerHTML = `
    ${screenHeader("フレンド", `${friends.length}人とつながっています`, "", "mypage")}

    ${friends.length === 0 ? `
    <div class="notice-panel">
      <span>🎵</span>
      <div>
        <strong>まだフレンドがいません</strong>
        <p>すれちがいでピースを交換するとフレンドになれます</p>
      </div>
    </div>` : `
    <div class="track-list section-block">
      ${friends.map((f) => {
        const enc = npcEncounterForUserId(f.userId);
        return `
        <div class="track-row" style="cursor:pointer;" data-open-friend="${f.userId}">
          <div style="width:48px;height:48px;border-radius:50%;background:var(--primary);display:flex;align-items:center;justify-content:center;font-size:18px;color:#fff;">🎵</div>
          <div style="min-width:0;">
            <strong>${f.userName}</strong>
            <p>${formatDate(f.addedAt)}にフレンドに${enc ? ` · 📍 ${enc.locationLabel}` : ""}</p>
          </div>
          <div style="text-align:right;">
            <strong style="display:block;font-size:12px;">交換 ${f.exchangeCount}回</strong>
            <span style="color:var(--muted);font-size:14px;">›</span>
          </div>
        </div>`;
      }).join("")}
    </div>`}
  `;
}

/* ═══════════════════════════════════════════════
   ⑩ フレンド詳細
═══════════════════════════════════════════════ */
function renderFriendDetail(state) {
  const friend = (state.friends || []).find((f) => f.userId === state.selectedFriendUserId);
  if (!friend) {
    document.querySelector("#friend-detail-screen").innerHTML = `
      ${screenHeader("フレンド", "", "", "friends")}
      <p style="text-align:center;color:var(--muted);font-size:12px;margin-top:40px;">フレンドが見つかりません</p>
    `;
    return;
  }

  const enc = npcEncounterForUserId(friend.userId);
  const friendDays = Math.max(1, Math.floor((Date.now() - friend.addedAt) / 86400000) + 1);

  document.querySelector("#friend-detail-screen").innerHTML = `
    ${screenHeader(friend.userName, enc ? `📍 ${enc.locationLabel}で出会いました` : "音楽でつながりました", "", "friends")}

    <div class="home-header" style="margin-bottom:14px;">
      <div class="avatar" style="display:flex;align-items:center;justify-content:center;font-size:22px;color:#fff;">🎵</div>
      <div class="home-user">
        <h1>${friend.userName}</h1>
        <p>${formatDate(friend.addedAt)}にフレンドになりました</p>
      </div>
    </div>

    <div class="section-block" style="padding:16px;">
      <div class="stat-grid">
        <div class="stat-tile"><span>フレンド歴</span><strong>${friendDays}日</strong></div>
        <div class="stat-tile"><span>交換回数</span><strong>${friend.exchangeCount}回</strong></div>
        <div class="stat-tile"><span>出会った場所</span><strong>${enc ? enc.locationLabel : "—"}</strong></div>
      </div>
      ${(state.oshiDeliveries || {})[friend.userId] ? `
        <p style="font-size:10px;color:var(--muted);margin-top:10px;text-align:center;">
          🎵 あなたの推し曲をこれまでに ${(state.oshiDeliveries || {})[friend.userId]}回 届けました
        </p>` : ""}
    </div>

    ${enc ? `
    <div class="section-block" style="margin-top:14px;padding:16px;">
      <div class="section-heading"><h2>音楽でつながった曲</h2></div>
      <div class="song-grid">
        ${enc.candidates.map((c) => getTrack(c.trackId)).filter(Boolean).map((t) => `
          <button class="song-tile" data-open-track="${t.id}" type="button">
            ${artBlock(t.color)}
            <strong>${isUnlocked(state, t.id) ? t.title : "未解放メロディ"}</strong>
            <span>${t.artistName}</span>
          </button>
        `).join("")}
      </div>
    </div>` : ""}
  `;
}

/* ─── アーティスト詳細画面 ──────────────────────── */
function renderArtistDetail(state) {
  const root = document.querySelector("#artist-detail-screen");
  if (!root) return;
  const artistId = state.selectedArtistId;
  if (!artistId) { root.innerHTML = ""; return; }
  const groups = artistGroups(state);
  const artist = groups.find((g) => g.id === artistId);
  if (!artist) { root.innerHTML = ""; return; }

  root.innerHTML = `
    ${screenHeader(artist.name, `曲パズル ${artist.completed} / ${artist.tracks.length} 完成`, "", "collection")}

    <div style="padding:4px 16px 16px;">
      <div style="display:flex;align-items:center;gap:14px;padding:16px;background:rgba(255,255,255,.04);border-radius:18px;margin-bottom:16px;">
        <img src="${ASSETS.artist}" alt="${artist.name}" style="width:64px;height:64px;border-radius:50%;object-fit:cover;flex:0 0 64px;">
        <div style="min-width:0;flex:1;">
          <h2 style="font-size:16px;font-weight:950;margin-bottom:4px;">${artist.name}</h2>
          <div class="piece-meter compact">
            <strong>${artist.completed}</strong>
            <span>/ ${artist.tracks.length} 曲完成</span>
          </div>
          <div class="progress" style="margin-top:6px;"><span style="--progress:${pct(artist.completed, artist.tracks.length)}%"></span></div>
        </div>
      </div>

      <p style="font-size:11px;font-weight:900;color:var(--muted);letter-spacing:.06em;margin-bottom:10px;">曲パズル一覧</p>
      <div style="display:grid;gap:10px;">
        ${artist.tracks.map((t) => {
          const owned = getOwned(state, t.id);
          const done  = owned.length >= t.pieceCount;
          return `
            <button class="song-tile" style="display:flex;align-items:center;gap:12px;width:100%;text-align:left;"
              data-open-track="${t.id}" type="button">
              <div class="art-block ${t.color}" style="width:52px;height:52px;border-radius:14px;flex:0 0 52px;"></div>
              <div style="min-width:0;flex:1;">
                <strong style="display:block;font-size:13px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                  ${isUnlocked(state, t.id) ? t.title : "未解放メロディ"}
                </strong>
                <span style="font-size:10px;color:var(--muted);">${t.artistName}</span>
                <div class="progress" style="margin-top:5px;"><span style="--progress:${pct(owned.length, t.pieceCount)}%"></span></div>
              </div>
              <div style="flex:0 0 auto;text-align:right;padding-left:4px;">
                <span style="font-size:11px;font-weight:900;color:${done ? "var(--mint)" : "var(--muted)"};">
                  ${done ? "完成!" : `${owned.length}/${t.pieceCount}`}
                </span>
              </div>
            </button>`;
        }).join("")}
      </div>
    </div>
  `;
}

/* ═══════════════════════════════════════════════
   renderAll
═══════════════════════════════════════════════ */
function renderAll() {
  const s = store.getState();
  renderHome(s);
  renderMelody(s);
  renderPieceSelect(s);
  renderMystery(s);
  renderPuzzle(s);
  renderCollection(s);
  renderRanking(s);
  renderPremium(s);
  renderPlaylist(s);
  renderShop(s);
  renderNotifySettings(s);
  renderBgSettings(s);
  renderMypage(s);
  renderFriends(s);
  renderFriendDetail(s);
  renderArtistDetail(s);
  renderModal(s);
  renderToast(s);
  renderPuzzleComplete(s);
  renderTitleCelebration(s);
  renderAuth(s);

  document.querySelectorAll(".screen").forEach((el) =>
    el.classList.toggle("active", el.dataset.screen === s.activeScreen));
  const parentTab = {
    "piece-select": "melody", mystery: "melody", puzzle: "collection",
    "artist-detail": "collection", friends: "mypage", "friend-detail": "mypage",
    premium: "mypage", shop: "mypage", "notify-settings": "mypage",
    "bg-settings": "mypage", playlist: "home",
  }[s.activeScreen] || s.activeScreen;
  document.querySelectorAll(".nav-item").forEach((el) => {
    const active = el.dataset.target === parentTab;
    el.classList.toggle("active", active);
    if (active) el.setAttribute("aria-current", "page");
    else el.removeAttribute("aria-current");
  });
}

/* ═══════════════════════════════════════════════
   モーダル
═══════════════════════════════════════════════ */
function renderModal(state) {
  const modal = document.querySelector("#modal");
  const CONTENT = {
    hint1:  ["広告を視聴してヒントを解放しますか？", "視聴すると以下の内容を解放できます。", "1つ目のヒントを見る"],
    hint2:  ["広告を視聴してヒントを解放しますか？", "視聴すると以下の内容を解放できます。", "2つ目のヒントを見る"],
    answer: ["広告を視聴してヒントを解放しますか？", "視聴すると以下の内容を解放できます。", "答えを見る"],
  };
  const content = CONTENT[state.selectedAdKind];
  if (!content) {
    modal.classList.remove("open");
    modal.setAttribute("aria-hidden", "true");
    return;
  }
  document.querySelector("#modal-title").textContent       = content[0];
  document.querySelector("#modal-body").textContent        = content[1];
  document.querySelector("#modal-reward-text").textContent = content[2];
  modal.dataset.kind = state.selectedAdKind;
  modal.classList.add("open");
  modal.setAttribute("aria-hidden", "false");
}

/* ═══════════════════════════════════════════════
   イベント
═══════════════════════════════════════════════ */
function normalize(v) {
  return v.toLowerCase()
    .replace(/[Ａ-Ｚａ-ｚ０-９]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0xfee0))
    .replace(/[^\p{Letter}\p{Number}]/gu, "");
}

function handleGuess(track) {
  const ans = window.prompt("曲名を入力してください");
  if (!ans) return;
  if (normalize(ans) === normalize(track.title)) {
    store.dispatch({ type: "UNLOCK_TRACK" });
  } else {
    window.alert("まだ違うようです。ヒントや試聴を使ってもう一度試してください。");
  }
}

document.addEventListener("click", (e) => {
  const t = (sel) => e.target.closest(sel);

  // 試聴は行全体のクリック（data-open-track 等）より優先
  if (t("[data-preview-track]")) {
    e.stopPropagation();
    openPreview(t("[data-preview-track]").dataset.previewTrack);
    return;
  }

  if (t("[data-target]"))        return store.dispatch({ type: "NAVIGATE", screen: t("[data-target]").dataset.target });
  if (t("[data-back]"))          return store.dispatch({ type: "NAVIGATE", screen: t("[data-back]").dataset.back });
  if (t("[data-open-track]"))    return store.dispatch({ type: "OPEN_TRACK", trackId: t("[data-open-track]").dataset.openTrack });

  // カルーセル
  if (t("[data-carousel='prev']")) { e.stopPropagation(); return store.dispatch({ type: "CAROUSEL_PREV" }); }
  if (t("[data-carousel='next']")) { e.stopPropagation(); return store.dispatch({ type: "CAROUSEL_NEXT" }); }
  if (t("[data-select-puzzle]"))       return store.dispatch({ type: "SELECT_PUZZLE" });
  if (t("[data-toggle-carousel-view]")) { e.stopPropagation(); return store.dispatch({ type: "TOGGLE_CAROUSEL_VIEW" }); }
  if (t("[data-switch-encounter]")) {
    e.stopPropagation();
    const dir = t("[data-switch-encounter]").dataset.switchEncounter;
    const order = seedData.encounterOrder;
    const s = store.getState();
    const cur = order.indexOf(s.activeEncounterId);
    const next = dir === "next" ? cur + 1 : cur - 1;
    if (next >= 0 && next < order.length) {
      return store.dispatch({ type: "SWITCH_ENCOUNTER", encounterId: order[next] });
    }
    return;
  }
  if (t("[data-switch-encounter-id]")) {
    e.stopPropagation();
    store.dispatch({ type: "SWITCH_ENCOUNTER", encounterId: t("[data-switch-encounter-id]").dataset.switchEncounterId });
    store.dispatch({ type: "NAVIGATE", screen: "melody" });
    return;
  }
  if (t("[data-next-encounter-id]")) {
    e.stopPropagation();
    store.dispatch({ type: "SWITCH_ENCOUNTER", encounterId: t("[data-next-encounter-id]").dataset.nextEncounterId });
    store.dispatch({ type: "NAVIGATE", screen: "melody" });
    return;
  }
  if (t("[data-back-to-carousel]"))    return store.dispatch({ type: "NAVIGATE", screen: "melody" });

  // ピース選択
  if (t("[data-pick-piece]")) {
    const n = Number(t("[data-pick-piece]").dataset.pickPiece);
    return store.dispatch({ type: "SELECT_PIECE", pieceNumber: n });
  }

  // コレクション内部タブ
  if (t("[data-collection-tab]")) {
    store.dispatch({ type: "SET_COLLECTION_TAB", tab: t("[data-collection-tab]").dataset.collectionTab });
    return;
  }

  // ランキング内部タブ
  if (t("[data-ranking-tab]")) {
    store.dispatch({ type: "SET_RANKING_TAB", tab: t("[data-ranking-tab]").dataset.rankingTab });
    return;
  }

  if (t("[data-guess-track]"))   return handleGuess(getTrack(t("[data-guess-track]").dataset.guessTrack));
  if (t("[data-dismiss-puzzle-complete]")) {
    const after = t("[data-dismiss-puzzle-complete]").dataset.after;
    store.dispatch({ type: "DISMISS_PUZZLE_COMPLETE" });
    if (after) store.dispatch({ type: "NAVIGATE", screen: after });
    return;
  }
  if (t("[data-listen-later]"))  return store.dispatch({ type: "ADD_LISTEN_LATER", trackId: t("[data-listen-later]").dataset.listenLater });
  if (t("[data-unlock-track]"))  return store.dispatch({ type: "UNLOCK_TRACK" });
  if (t("[data-ad]")) {
    // 解放手段の優先順: プレミアム（広告非表示）> ヒントチケット消費 > 広告確認モーダル
    const kind = t("[data-ad]").dataset.ad;
    const cur = store.getState();
    if (cur.premium) return store.dispatch({ type: "COMPLETE_AD", kind });
    if ((cur.hintTickets || 0) > 0) return store.dispatch({ type: "COMPLETE_AD", kind, viaTicket: true });
    return store.dispatch({ type: "OPEN_AD_MODAL", kind });
  }
  if (t("[data-add-friend-confirm]")) {
    const pf = store.getState().pendingFriendAdd;
    if (pf) store.dispatch({ type: "ADD_FRIEND", userId: pf.userId, userName: pf.userName });
    return;
  }
  if (t("[data-dismiss-friend-prompt]")) return store.dispatch({ type: "DISMISS_FRIEND_PROMPT" });
  if (t("[data-dismiss-title-celebration]")) return store.dispatch({ type: "DISMISS_TITLE_CELEBRATION" });
  if (t("[data-premium-join]"))   return store.dispatch({ type: "SET_PREMIUM", value: true });
  if (t("[data-premium-cancel]")) return store.dispatch({ type: "SET_PREMIUM", value: false });
  if (t("[data-buy-item]"))       return store.dispatch({ type: "BUY_SHOP_ITEM", itemId: t("[data-buy-item]").dataset.buyItem });
  if (t("[data-equip-deco]"))     return store.dispatch({ type: "EQUIP_DECORATION", itemId: t("[data-equip-deco]").dataset.equipDeco });
  if (t("[data-toggle-notification]")) return store.dispatch({ type: "TOGGLE_NOTIFICATION", key: t("[data-toggle-notification]").dataset.toggleNotification });
  if (t("[data-digest-time]"))    return store.dispatch({ type: "SET_DIGEST_TIME", value: t("[data-digest-time]").dataset.digestTime });
  if (t("[data-toggle-bg]"))      return store.dispatch({ type: "TOGGLE_BG_SCAN", key: t("[data-toggle-bg]").dataset.toggleBg });
  if (t("[data-bg-mode]"))        return store.dispatch({ type: "SET_BG_SCAN_MODE", value: t("[data-bg-mode]").dataset.bgMode });
  if (t("[data-link-service]"))   return store.dispatch({ type: "TOGGLE_SERVICE_LINK", service: t("[data-link-service]").dataset.linkService });
  if (t("[data-open-friend]"))  return store.dispatch({ type: "OPEN_FRIEND", userId: t("[data-open-friend]").dataset.openFriend });
  if (t("[data-open-artist]"))  return store.dispatch({ type: "OPEN_ARTIST", artistId: t("[data-open-artist]").dataset.openArtist });
  if (t("[data-toggle-oshi]"))  return store.dispatch({ type: "TOGGLE_OSHI_TRACK", trackId: t("[data-toggle-oshi]").dataset.toggleOshi });
});

document.querySelector("#close-modal").addEventListener("click",  () => store.dispatch({ type: "CLOSE_AD_MODAL" }));
document.querySelector("#cancel-modal").addEventListener("click",  () => store.dispatch({ type: "CLOSE_AD_MODAL" }));
document.querySelector("#confirm-modal").addEventListener("click", () =>
  store.dispatch({ type: "COMPLETE_AD", kind: store.getState().selectedAdKind }));

/* ═══════════════════════════════════════════════
   音楽検索（Go API → localフォールバック）
═══════════════════════════════════════════════ */
function localSearchTracks(q) {
  if (!q) return Object.values(seedData.tracks).map((t) => ({
    trackId:    t.id,
    title:      t.title,
    artistName: t.artistName,
    color:      t.color,
  }));
  const lq = q.toLowerCase();
  return Object.values(seedData.tracks)
    .filter((t) => t.title.toLowerCase().includes(lq) || t.artistName.toLowerCase().includes(lq))
    .map((t) => ({
      trackId:    t.id,
      title:      t.title,
      artistName: t.artistName,
      color:      t.color,
    }));
}

function renderSearchResults(results, isApi) {
  const box = document.getElementById("search-results");
  if (!box) return;
  if (results.length === 0) {
    box.innerHTML = `<p class="search-empty">該当する曲が見つかりませんでした</p>`;
    box.style.display = "block";
    return;
  }
  const source = isApi
    ? `<span class="search-source api">Go API</span>`
    : `<span class="search-source local">ローカル</span>`;
  box.innerHTML = results.map((r) => `
    <div class="search-result-item" data-open-track="${r.trackId}">
      <div class="search-result-dot" style="background:var(--color-${r.color}, var(--primary));"></div>
      <div class="search-result-text">
        <strong>${r.title}</strong>
        <span>${r.artistName}</span>
      </div>
    </div>
  `).join("") + `<div class="search-result-footer">${source} · ${results.length}件</div>`;
  box.style.display = "block";
}

let searchTimer = null;
document.addEventListener("input", async (e) => {
  if (e.target.id !== "track-search-input") return;
  const q = e.target.value.trim();
  const box = document.getElementById("search-results");
  if (!q) { if (box) box.style.display = "none"; return; }
  clearTimeout(searchTimer);
  searchTimer = setTimeout(async () => {
    const apiResults = await apiSearch(q);
    if (apiResults !== null) {
      renderSearchResults(apiResults, true);
    } else {
      renderSearchResults(localSearchTracks(q), false);
    }
  }, 250);
});

document.addEventListener("focusin",  (e) => {
  if (e.target.id === "track-search-input" && e.target.value.trim()) {
    document.getElementById("search-results")?.style && (document.getElementById("search-results").style.display = "block");
  }
});
document.addEventListener("focusout", (e) => {
  if (e.target.id === "track-search-input") {
    setTimeout(() => { const b = document.getElementById("search-results"); if (b) b.style.display = "none"; }, 150);
  }
});

// ログイン中の操作をSupabaseへ都度反映
let prevSyncState = store.getState();
store.subscribe((state, action) => {
  syncAfterAction(syncedUserId, prevSyncState, state, action);
  prevSyncState = state;
});

store.subscribe(renderAll);
renderAll();
