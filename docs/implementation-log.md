# StreetMelody 実装記録

このファイルは、StreetMelodyで実装した内容を毎回記録するためのログです。

## 現在の実装状態サマリー（2026-06-17 時点）

### アーキテクチャ

```text
Webプロトタイプ（apps/web/）: 静的SPA・ES Modules・LocalStorage永続化・port 5174
Go API（main.go + api/）: 曲検索・カタログ提供・port 3001
Supabase（StreetMelody / ap-northeast-1）: PostgreSQL（RLS・9テーブル）+ Auth
```

### 実装済み機能一覧

| 分類 | 機能 | 状態 |
|---|---|---|
| コア | 8画面（ホーム/メロディ/ピース選択/未解放/パズル/コレクション/ランキング/マイページ） | ✅ |
| コア | 24ピースパズル（6×4実画像・所持グリッド・モザイク⇄ピース切替） | ✅ |
| コア | 初期ピース1〜7枚ランダム（三角分布） | ✅ |
| コア | メロディコイン（新規+1 / 完成後重複+3） | ✅ |
| コア | 伏せ字・広告ヒント段階解放・YouTube確認フロー | ✅ |
| コア | パズル完成演出（パーティクル・曲名自動解放）【A-1】 | ✅ |
| すれちがい | 出会い5件・順番制フロー（進捗ドット・ロック・自動前進）【A-2】 | ✅ |
| すれちがい | 同一ユーザークールタイム6時間（バナー表示） | ✅ |
| すれちがい | ピース取得後のフレンド申請（追加/スキップ） | ✅ |
| 試聴 | YouTube 30秒試聴（音声のみ・サビ位置・波形UI） | ✅ |
| 試聴 | 試聴回数制限 1曲1日3回（残回数表示・日付リセット）【A-3】 | ✅ |
| バックエンド | Supabase プロジェクト・スキーマ・シード・RLS【B-1】 | ✅ |
| バックエンド | Go API の Supabase カタログ連携・`/api/search` | ✅ |
| 認証 | ログイン画面（メール/Google/Apple/LINE/ゲスト）【B-2】 | ✅ |
| 認証 | ゲスト機能制限（フレンド・ランキング不可＋登録導線） | ✅ |
| 認証 | Google/Apple OAuth・LINE OIDC・匿名認証の有効化 | ⏳ ダッシュボード設定待ち |
| バックエンド | ピース・コレクションのSupabase同期（ログイン時マージ＋都度反映）【B-3】 | ✅ |
| その他 | 音楽検索（Go API + ローカルフォールバック） | ✅ |
| マイページ | フレンド一覧・フレンド詳細画面（音楽でつながった履歴）【C-1】 | ✅ |
| ホーム | デイリーミッション（ピース5個獲得でコイン+10）【C-2】 | ✅ |
| コレクション | アーティストタブの実計算化（全アーティスト・完成数連動）【C-3】 | ✅ |
| コレクション | 称号タブ（8種・達成条件・進捗バー・獲得演出）【C-3】 | ✅ |
| すれちがい | フレンド交換回数の実イベント連動（再交換で+1・Supabase同期）【C-4】 | ✅ |
| ドキュメント | SwiftUI / Jetpack Compose 移植対応表（docs/native-porting-map.md）【C-5】 | ✅ |
| すれちがい | クールタイム明け（6時間経過）の出会いが再度受信可になる日次リフレッシュ【D-1】 | ✅ |
| マイページ/コレクション | 推し曲設定（解放済みの曲から最大3曲・トグル）【D-2】 | ✅ |
| コレクション | 称号獲得時のトースト・獲得演出オーバーレイ【E-1】 | ✅ |
| コア | 経験値・レベルアップ（新規ピース+5 / 完成+50・レベルバー連動）【E-2】 | ✅ |
| ランキング | 自分の順位の実データ算出（所持ピース数・友達タブはフレンド連動）【E-3】 | ✅ |
| コア | パズル完成報酬コインの実付与（rewardCoins 100枚）【F-1】 | ✅ |
| マイページ | プレミアムプラン（模擬加入・広告スキップ・推し曲5曲・エリアランキング）【F-2】 | ✅ |
| ホーム | 今日のメロディプレイリスト画面（ヒーローパネルから遷移）【F-3】 | ✅ |
| マイページ | ショップ（ヒントチケット・ランダムピース・アバター装飾の購入/装備）【G-1】 | ✅ |
| マイページ | 通知設定画面（即時/まとめ通知・時間帯・項目別トグルの永続化）【G-2】 | ✅ |
| マイページ | 音楽サービス連携の模擬実装（Spotify/Apple Music/YouTube Music）【G-3】 | ✅ |
| マイページ | バックグラウンド検知の設定画面（ON/OFF・スキャン頻度・夜間停止）【H-1】 | ✅ |
| コレクション | 称号の常設リワード（獲得時にコイン/EXPボーナス・演出/タブに報酬表示）【H-2】 | ✅ |
| すれちがい | 推し曲のすれちがい連動（交換時に自分の推し曲を相手へ配達・回数記録）【H-3】 | ✅ |
| ホーム | 通知バナーと通知設定の連動（即時通知OFFで🔕バナー・まとめ通知表示に切替）【I-1】 | ✅ |
| コレクション | アーティスト詳細ページ（アーティストタブの「詳細 ›」から曲パズル一覧へ遷移）【I-2】 | ✅ |

---

## 2026-06-04

- 仕様書を読み、主要体験を「近距離で届いたメロディの確認」「5枠からのピース選択」「未解放曲の伏せ字・試聴・広告ヒント」「曲パズル進行」「アーティストパズル」「今日のメロディプレイリスト」として整理。
- 依存関係なしで動作する静的SPAを新規作成。
- `index.html` に主要6画面と広告確認モーダルの土台を追加。
- `src/styles.css` に仕様書のカラーパレット、角丸、柔らかい影、ぷっくりしたカード・ボタン・下部タブのUIを実装。
- `src/app.js` に画面遷移、ピース候補選択、未解放曲への遷移、広告確認モーダル、ヒント段階の更新を実装。
- `assets/` にメロディコイン、パズルピース、ヒントチケット、マスコット、パズルカバー、背景装飾、アーティスト画像のSVG素材を追加。
- ブラウザ検証で見つかった日本語ラベル・数値・ミッションカード見出しの折り返しとページ全体スクロールバーをCSSで調整。

### 本実装フェーズ1

- `index.html` を ES Modules 前提に変更。
- `src/data.js` を追加し、ユーザー、楽曲、アーティスト、近距離交換候補、今日のメロディプレイリストのシードデータを分離。
- `src/store.js` を追加し、画面状態、選択中トラック、所持ピース、ヒント段階、YouTube確認リンク表示状態、解放済み曲、あとで聴くをLocalStorageへ永続化。
- `src/app.js` を再構成し、画面描画とイベント接続をストア駆動に変更。
- ピース候補選択時に所持ピースを追加し、未解放曲は未解放画面、解放済み曲はパズル画面へ遷移するように実装。
- 「答えを見る」は広告確認後にYouTube確認導線を表示し、「確認する」で曲名・アーティスト名を解放する段階フローに変更。
- 曲パズル画面の所持ピース数と進行バーをストアの所持ピースから算出するように変更。
- `package.json` を追加し、`npm run check` と `npm run test:store` で構文チェックとストア永続化テストを実行できるようにした。
- Browserでホーム、ピース選択、未解放曲、広告確認、YouTube確認相当の解放、パズル画面までの主要フローを確認。

### 本実装フェーズ2

- 参考UIに合わせて各画面のHTML構造・CSSを全面改修。
  - ホーム：「近距離交換をはじめる」ボタン、通知バッジ、レベルバー、コレクション実計算
  - ピース選択：横スクロールカード列、選択状態ハイライト、固定「このピースを選ぶ」ボタン
  - 未解放メロディ：★マスク表示、🎫チケットアイコン付きヒントボタン、「あとで確認」
  - 広告モーダル：マスコット配置、「※広告視聴後はキャンセルできません」注釈
  - アーティスト：アーティストパズル進行バッジ、3状態ステータスバッジ、NEWバッジ
  - 曲パズル：パズルSVGアセット使用、空ピースのグレー表示
- UIのハードコード値をすべて実状態から計算するように修正。
  - コレクション統計（曲パズル完成数、アーティスト数、プレイリスト数）をstoreから算出
  - `collectionSummary` を `seedData` から削除
  - 今日のメロディのピース進行をプレイリスト先頭曲の `collectedPieces` から算出
  - アーティスト画面「あと○曲」を `totalTrackPuzzles - completedTrackPuzzles` で計算
- `server/` ディレクトリにNode.js APIサーバーを新規作成（`npm run api` で起動 / port 3001）。
  - `server/schema.sql`：PostgreSQLテーブル定義（users / artists / tracks / collected_pieces / encounters など12テーブル）
  - `server/db/client.js`：インメモリストア（開発用）＋クエリヘルパー関数群
  - `server/db/seed.js`：初期データ定義
  - `server/routes/tracks.js`：GET /api/tracks, GET /api/tracks/:id, POST unlock/pieces/hint
  - `server/routes/users.js`：GET /api/me, /collection, /mission, POST listen-later
  - `server/routes/encounters.js`：GET /api/encounters/today, POST select
  - `server/routes/playlist.js`：GET /api/playlist/daily
  - `server/middleware/cors.js`：CORS・JSONレスポンスヘルパー
  - `server/index.js`：ルーティングテーブルとHTTPサーバー起動

### UI再作成フェーズ

- Goインストール確認として `go version` を実行し、`go1.26.4 darwin/arm64` を確認。
- UI崩れの原因になっていた画面テンプレートとCSSを0ベースで再作成。
- `src/app.js` を全面整理し、インラインスタイルを排除して、状態管理・データ定義を維持したまま表示レイヤーを差し替え。
- `src/styles.css` を全面差し替えし、モバイル優先の安定したカード、ヘッダー、下部タブ、候補カード、パズル、モーダル、トーストへ再定義。
- ホーム画面を「ユーザー状態」「今日のメロディ」「コレクション」「ミッション」「最近追加した曲」の縦積み構成へ変更。
- ピース選択画面を横スクロール候補カード + 画面下部の確定ボタンに整理。
- 未解放曲、曲パズル、アーティスト、プレイリスト画面も同じUI基準で再構成。
- `npm run check` と `npm run test:store` を実行し、構文チェックとストア永続化テストが通ることを確認。
- Browserでホーム、ピース候補選択、候補確定、パズル、アーティスト画面のDOM状態とテキスト溢れを確認。

### UIフォント・変数化修正

- UI全体のフォントサイズを縮小。
  - body: 12px
  - ホームユーザー名・画面タイトル: 15px
  - メインのピース数表示: 20px
  - ボタン: 12px
- `status: "あと3ピース"` のような派生表示値を `src/data.js` から削除。
- `6 / 9`、`3 / 5`、完成までの残りピース、プレイリスト曲の状態表示を `state.collectedPieces`、`pieceCount`、`mission.current`、`mission.target` から算出する形に変更。
- `app.js` に残っていた日本語UI文言を `src/data.js` の `UI_TEXT` へ移動。
- プレイリストサブタイトルと出会いサマリーを `dailyPlaylist.encounterId` と `encounters[].summary` から生成するように変更。
- `rg` で `app.js` 内の日本語直書き、固定進行値、`status` 参照が残っていないことを確認。
- `npm run check` と `npm run test:store` を実行し、構文チェックとストア永続化テストが通ることを確認。

### 仕様変更反映

- **未解放メロディのマスク仕様変更**
  - アーティスト名は常に表示するよう変更（旧: アーティスト名も伏せ字）
  - 曲名の伏せ字を `○` から `?`（文字数に合わせた個数）に変更
  - `masks` → `titleMasks`（タイトルのみ）にデータ構造を変更
  - `maskForTrack` を `${artistName} / ${titleMask}` 形式に更新
  - ホームの「最近追加した曲」でも未解放曲のアーティスト名を表示するよう修正

- **ピース候補選択画面のタイマー削除**
  - 残り時間（`00:45` 等）の表示を削除
  - `encounter.expiresInSeconds` の参照を除去

- **メロディコイン取得ルール追加**
  - ピース新規獲得時: +1枚
  - パズル全揃い後の重複ピース取得時: +3枚
  - `state.coins` をストア管理に追加（LocalStorage 永続化）
  - ホームのコイン表示を `seedData.user.coins` → `state.coins` に変更

- **開発サーバー改善 (`apps/web/serve.py`)**
  - ESModule のキャッシュ問題を解決するため全JSファイルのインポート文にタイムスタンプを動的付与
  - HTML・JS すべてに `Cache-Control: no-store` を付与

- **仕様書（Obsidianmd）更新**
  - 開発計画書 §10: アーティスト名公開・`?`マスク・ヒント段階の例を更新
  - 開発計画書 §8.2: メロディコイン取得ルール表を追加
  - UI設計書 §5.2: 残り時間削除・コイン表示仕様を更新

### モザイク調整・YouTube 30秒試聴機能（音声専用・サビ位置再生）

- **モザイク強度を緩和** — `filter:blur(22px) brightness(0.55)` → `blur(12px) brightness(0.78)` に変更。全体の輪郭が薄く感じ取れる程度に調整。

- **YouTube IFrame 30秒試聴（音声専用・サビ位置から再生）**
  - `apps/web/src/data.js`: 全8曲（実YouTube IDあり）に `chorusStart`（サビ開始秒数）を追加。
    - Pretender:57s / Lemon:68s / 夜に駆ける:52s / 唱:44s / 怪獣の花唄:38s / Anytime Anywhere:58s / ブルーベリー・ナイツ:55s / ハルジオン:62s
  - `index.html`: 試聴モーダル `#preview-modal` を音声プレイヤーUIに再設計。
    - `#preview-player` をモーダル外の `position:fixed; left:-9999px` に移動し、映像を非表示のまま音声だけ再生。
    - 13本のバーが異なるタイミングで上下する CSS 波形アニメーション（`@keyframes wave-bar`）を表示。
    - 再生完了・停止時は `.stopped` クラスで波形をフラット化。
    - ダーク背景 `#1a1030` のオーディオプレイヤー風デザイン。
  - `apps/web/src/app.js`: `openPreview(trackId)` を更新。
    - `YT.Player` に `playerVars: { autoplay:1, controls:0, start: track.chorusStart }` を渡してサビから自動再生。
    - `display:none` ではなくオフスクリーン配置で再生継続を保証。
    - 30秒カウントダウン完了後に `pauseVideo()`、未解放曲はヒントLv1自動付与。
  - 架空曲（`youtubeVideoId` が `"official-"` 始まり）はアラートで試聴不可を通知。
  - メロディカルーセルの曲名下に「▶ 少し聴く」ボタンを追加。未解放メロディ画面にも設置済み。

次の候補:

- 音楽検索・公式MV判定・正規パズル画像DBのAPIモックを追加する。
- 近距離交換イベントと通知制限のドメインロジックを追加する。
- Go API / PostgreSQL スキーマ / 管理画面の最小構成を追加する。
- SwiftUI / Jetpack Compose へ移植する場合の画面コンポーネント対応表を作成する。

## 2026-06-09

### フロー確認・UI改修・パズル画像生成

**実装対象ディレクトリ**: `apps/web/src/`（開発サーバーが配信する実ファイル）
※ルートの `src/` は古い並行コピーのため対象外。

- **ピース候補確定→ピース選択フローの動作確認**
  - メロディ画面（カルーセル）→「このパズルにする」→ ピース選択画面（6×4 = 24ピースグリッド）→ ピース取得 → 未解放メロディ画面 の一連フローを通し確認。
  - `SELECT_PUZZLE` → `activeScreen: "piece-select"` → `SELECT_PIECE` → `activeScreen: mystery/puzzle` の遷移が正常動作していることを確認。
  - 「パズルを選び直す」ボタンでカルーセルへ戻る動作も確認。
  - ピース取得時のトースト（`メロディコイン ×1`）表示も確認。

- **背景装飾の削除**
  - `apps/web/src/styles.css`: `body` の `radial-gradient` 装飾を削除し、`background: #f8f4fc` に変更。
  - `apps/web/src/styles.css`: `.app-shell` の `url("../assets/bg-doodles.svg")` 背景パターン（格子模様アイコン）を削除。
  - `apps/web/src/styles.css`: `.art-block::after` の格子状ハイライトオーバーレイを削除。

- **プレースホルダーのグリーンバック化**
  - `apps/web/src/styles.css`: `.art-block` および `.art-block.sunset/violet/berry/magic` のカラーグラデーションを `background: #3ecf6b`（グリーンバック）に統一。
  - `apps/web/src/styles.css`: `.avatar` の `background` をグリーンバックに変更。
  - 意図：実画像が差し込まれていない箇所が一目でわかるようにする。本番画像が入った箇所（Pretenderなど）は上書きされるため影響なし。

- **未実装曲のパズル画像生成（グリーンバック仮画像）**
  - `puzzle_test/generate_puzzle.py` を使い、9曲分のグリーンバックサムネイル（1200×672px）からピース24枚を生成。
  - 生成対象：`track_sunset_drive` / `track_lemon` / `track_yoru` / `track_show` / `track_kaiju` / `track_anytime` / `track_blueberry` / `track_magic_hour` / `track_halzion`
  - 各曲の出力先：`apps/web/assets/puzzles/{track_id}/piece_01.png ~ piece_24.png` および `preview.png`

- **`PUZZLE_ASSETS` を全曲対応に更新**
  - `apps/web/src/data.js`: `PUZZLE_ASSETS.tracks` に全9曲を追加。
  - コメントで `✓ 本番画像`（Pretender）と `★ greenback`（仮画像）を区別。
  - これにより、ピース選択グリッドで所持ピースがグリーン画像、未所持ピースが暗い lockedピースとして正しく表示される。

### 本番YouTubeサムネイル差し替え

- YouTube画像CDN（`https://img.youtube.com/vi/{videoId}/maxresdefault.jpg`）からAPIキー不要でサムネイルを取得。
- `generate_puzzle.py`（`puzzle_test/.venv` 環境）でサムネイルを24ピース＋preview.pngに分割。
- 差し替え対象8曲（実YouTube IDあり）:

| トラックID | 曲名 | アーティスト | YouTube ID |
|---|---|---|---|
| track_pretender | Pretender | Official髭男dism | TQ8WlA2GXbk |
| track_lemon | Lemon | 米津玄師 | SX_ViT4Ra7k |
| track_yoru | 夜に駆ける | YOASOBI | x8VYWazR5mE |
| track_show | Show | King Gnu | pgXpM4l_MwI |
| track_kaiju | 怪獣の花唄 | Vaundy | UM9XNpgrqVk |
| track_anytime | Anytime | ATARASHII GAKKO! | r105CzDvoo0 |
| track_blueberry | ブルーベリー・ナイツ | マカロニえんぴつ | Euf1-3WRino |
| track_halzion | ハルジオン | YOASOBI | kzdJkT4kp-A |

- ハルジオン: `maxresdefault` が存在せず11KB（小サイズ）のため `hqdefault.jpg` を使用。
- 架空曲2曲（`track_sunset_drive` / `track_magic_hour`）はグリーンバック仮画像のまま維持。
- `apps/web/src/data.js`: `seedData.tracks` の `youtubeVideoId` と `thumbnailUrl` を全曲分更新。
  - `track_blueberry` のタイトルも `"ブルーベリー"` → `"ブルーベリー・ナイツ"` に修正。
  - 架空曲の `thumbnailUrl` を `ASSETS.cover` → `./assets/puzzles/{track_id}/preview.png` に統一。

### 音楽検索・Go API 最小構成

- **Go API コンパイルエラー修正**
  - `backend/api/go.mod` の module 名が `streetmelody` なのに import が `streetmelody/api/handler` になっていた。
  - `main.go` / `handler/handler.go` / `store/store.go` の import を `streetmelody/handler` 等に修正。
  - `go build ./...` が通ることを確認。

- **シードデータ更新（`backend/api/store/store.go`）**
  - 全曲の `PieceCount` を 9 → 24 に修正（6×4 グリッドと一致）。
  - `track_pretender`（Official髭男dism）を追加。計10曲。
  - `track_blueberry` タイトルを `"ブルーベリー"` → `"ブルーベリー・ナイツ"` に修正。
  - `track_show` artistID → `artist_kingu_gnu`（King Gnu）、`track_anytime` artistID → `artist_atarashii`（ATARASHII GAKKO!）に修正。
  - `artist_kingu_gnu` / `artist_atarashii` を Artists に追加（計10アーティスト）。

- **音楽検索エンドポイント追加（`GET /api/search?q=...`）**
  - `store.SearchTracks(q)`: タイトル・アーティスト名に対してキーワード検索、最大20件返却。
  - `handler.searchTracks`: `/api/search` ルートを追加。
  - レスポンス: `{ query, results: [{trackId, title, artistName, color, youtubeId}] }`

- **SPA への API 統合（`apps/web/src/`）**
  - `apps/web/src/api.js` を新規作成（3秒タイムアウト付き fetch ラッパー）。
  - `apps/web/src/app.js`: コレクション画面に検索バーUI追加。250ms デバウンスで API 検索、未起動時はローカルフォールバック。結果に「Go API / ローカル」取得元ラベル表示。
  - `apps/web/src/styles.css`: 検索バー・ドロップダウン・バッジのスタイルを追加。

### クールタイム・モザイク切り替え・UI改善

- **同一ユーザーとのクールタイム 6時間**
  - `data.js`: encounter に `fromUserId`, `fromUserName` を追加。`initialAppState()` に `encounterCooldowns: {}` を追加。
  - `store.js`: `SELECT_PIECE` 時に `encounterCooldowns[encounterId] = Date.now()` を記録。LocalStorage に永続化。
  - `app.js`: `cooldownRemaining()` / `formatCooldown()` ヘルパーを追加。メロディ画面ヘッダー下にクールタイムバナー（⏳ ユーザー名・残り時間）を表示。

- **カルーセルモザイク↔ピース確認 切り替え**
  - `data.js`: `initialAppState()` に `carouselViewMode: "pieces"` を追加。
  - `store.js`: `TOGGLE_CAROUSEL_VIEW` アクション追加。`CAROUSEL_NEXT/PREV` でビューモードを "pieces" にリセット。
  - `app.js`: カード左上に切り替えボタン（「🎵 フル表示」/「🧩 ピース確認」）を追加。モザイクモードは `filter: blur(12px) brightness(0.78)` で全体をぼかした表示（後に調整済み）。

- **未所持ピースの背景改善**
  - `puzzleGridMini()`: 未所持セルを `opacity:.35` の真っ暗から `background:#3a3060` + `outline:1px solid rgba(255,255,255,.18)` + `opacity:0.55` に変更。セル間のギャップ色も紫系 `rgba(80,60,140,.5)` に変更し、枠が視覚的に見えるように改善。

### カルーセル表示変更・初期ピース数ランダム化（仕様変更）

- **メロディ画面カルーセル：サムネイル全体表示 → 所持状況パズルグリッドへ変更**
  - `apps/web/src/app.js`: `puzzleGridMini(state, trackId)` ヘルパーを追加。
  - カルーセルのメインカード内をサムネイル `<img>` から 6×4 ピースグリッドに差し替え。
  - 所持ピース: 実ピース画像 + 緑オーバーレイ表示。
  - 未所持ピース: locked ピース画像、opacity 0.35 で暗く表示。
  - カード右下に `n / 24` の所持数バッジを常時表示。
  - ユーザーが出会ったパズルについて「自分が何枚持っているか」を直感的に把握できる仕様へ変更。

- **初期ピース数：0枚固定 → 1〜7枚ランダム（三角分布）**（仕様変更）
  - `apps/web/src/data.js`: `initialAppState()` の `collectedPieces` を変更。
  - `ownedPieces: []` のトラックに三角分布で 1〜7 枚を生成。
  - 式: `count = clamp(round(1 + 3 * (rand() + rand())), 1, 7)` → 期待値 4、最頻値 ≈ 4。
  - `ownedPieces` が設定済みのトラック（プロトタイプサンプル）はそのまま維持。

### A-1: パズル完成演出

- `data.js`: `initialAppState()` に `puzzleCompleteTrackId: null` を追加。
- `store.js`: `SELECT_PIECE` で `justCompleted` 判定（初めて全ピース揃った）。完成時は曲名を自動解放（`unlockedTrackIds` へ追加）し `puzzleCompleteTrackId` をセット。`DISMISS_PUZZLE_COMPLETE` アクション追加。
- `index.html`: `<div id="puzzle-complete-root">` を追加。
- `app.js`: `renderPuzzleComplete(state)` — フルスクリーンオーバーレイ（z-index 300〜302）。ダーク背景 + 28個のパーティクル（CSS `@keyframes pcParticle`）+ バウンス入場カード（`pcIn`）。完成画像・🎉 パズル完成！・曲名・アーティスト・ピース数/コインバッジ・「コレクションで見る」「閉じる」ボタン。

### A-2: 複数すれちがい + 順番制フロー + フレンド機能

- **出会いデータ 5件**（`data.js`）: 田中ゆき(大学)・佐藤けんじ(渋谷駅)・鈴木あや(カフェ)・山田たろう(図書館)・中村みか(コンビニ)。`encounterOrder` 配列で順序を定義。
- **順番制フロー**: 出会いは1人ずつ順番に確認する（自由切り替え不可）。
  - メロディ画面上部に進捗バー（n / 5 件目・ドットインジケーター: 緑=済 / 紫=今ここ / 薄=未確認）。
  - 「今日の出会い」リスト: 確認済み=✓済バッジ、現在=「→ 今ここ」、未来=🔒順番待ち（タップ不可・薄表示）。
  - `store.js`: `SELECT_PIECE` 後に `nextUnvisitedEncounter()` で次の未確認出会いへ自動前進。
  - mystery/puzzle 画面下部に「n人目の出会いへ ›」ボタン（`nextEncounterButton()`）。全確認済みなら「🎉 今日の出会いを全て確認しました」。
- **フレンド機能**（開発計画書「フレンド機能・音楽共有」§準拠・近距離交換後のフレンド申請導線）:
  - `data.js`: `friends: []`, `pendingFriendAdd: null` を初期状態に追加。
  - `store.js`: `ADD_FRIEND` / `DISMISS_FRIEND_PROMPT` アクション。ピース取得時に相手が未フレンドなら `pendingFriendAdd` をセット。
  - `app.js`: `friendPromptCard()` — ピース取得後の画面に「○○さんとメロディでつながりました／フレンドに追加・スキップ」カードを表示。フレンドには 🎵 マーク。
  - ホーム画面の「今日n件のメロディ」はクールタイム未消化の出会い数を動的にカウント。

### A-3: 試聴回数制限（1曲1日3回）

- `data.js`: `previewPlays: {}` を初期状態に追加（`{ [trackId]: { date, count } }`、日付単位でリセット）。
- `store.js`: `RECORD_PREVIEW_PLAY` アクション（日付が変わればカウント1から）。`SHOW_TOAST` アクション追加。LocalStorage に永続化。
- `app.js`: `PREVIEW_DAILY_LIMIT = 3`、`previewPlaysLeft(state, trackId)` ヘルパー。
  - `openPreview()` 冒頭で残回数チェック → 0ならトースト「本日の試聴回数を使い切りました（1日3回まで）」を表示して再生しない。再生時に `RECORD_PREVIEW_PLAY` を dispatch。
  - カルーセルの試聴ボタン: 「▶ 少し聴く（あと n 回）」/ 使い切り時はグレー無効ボタン。
  - 試聴モーダル内に「本日あと n 回試聴できます」表示（`#preview-plays-left`）。
  - 未解放メロディ画面: 再生FABを減光 + 「（試聴 本日あとn回）」表示。

### B-1: Supabase 新規プロジェクト + Go API 接続

- **Supabaseプロジェクト**: `StreetMelody`（ref: `wngtvdgzzlkajtbwsurc` / ap-northeast-1 東京 / 無料プラン）
  - URL: `https://wngtvdgzzlkajtbwsurc.supabase.co`
  - publishable key: `sb_publishable_oR41TcNHu-G9La0JHrnmWg_P8SfRts5`（anon・公開前提）
- **スキーマ**（migration: `initial_schema`）: `artists` / `tracks` / `profiles` / `collected_pieces` / `unlocked_tracks` / `encounters` / `encounter_candidates` / `encounter_cooldowns` / `friendships`
  - 全テーブル RLS 有効。マスタ（artists/tracks/encounters/candidates）は全員 select 可、ユーザーデータは `auth.uid()` 本人のみ。
  - `handle_new_user()` トリガー: サインアップ時に `profiles` 行を自動作成（`is_anonymous` → `is_guest`）。PostgREST からの EXECUTE は revoke 済み。
- **シード**: プロトタイプ `data.js` と同一の8アーティスト・10曲（chorusStart含む）・出会い5件・候補17件。
- **Go API**（`api/store/supabase.go` 新規）:
  - 起動時に PostgREST（`/rest/v1/artists`, `/rest/v1/tracks`）からカタログ取得しインメモリストアを置き換え。
  - 失敗時は埋め込みシードで継続（フォールバック）。env: `SUPABASE_URL` / `SUPABASE_ANON_KEY`（デフォルト値あり）。
  - `/api/search?q=` エンドポイントを handler に追加（フロント `api.js` が期待する `{results: [{trackId,title,artistName,color,youtubeId}]}` 形式）。
  - 動作確認: `q=yoasobi` → 夜に駆ける + ハルジオン（YouTube ID 付き）が Supabase カタログから返る。

### B-2: 認証最小構成（Supabase Auth）

- **`apps/web/src/supabase.js`**（新規）: `@supabase/supabase-js@2` を esm.sh CDN から import。
  - `getAuthUser()` / `signUpEmail()` / `signInEmail()` / `signInOAuth()` / `signInGuest()` / `signOut()` / `onAuthChange()`。
  - ゲスト: `signInAnonymously()` 失敗時（匿名認証無効時）は「ローカルゲスト」へフォールバック（`streetmelody.localGuest` フラグ・端末内のみ）。
- **ログイン画面**（`#auth-root` フルスクリーンオーバーレイ・z-index 400）:
  - ✉️ メール（ログイン/新規登録フォーム）・Google・Apple・LINE・ゲストの5導線。
  - メール新規登録 → 確認メール送信を通知。OAuth 未設定時はエラーメッセージで案内。
  - LINE はカスタム OIDC 連携前提（プロトタイプでは未設定通知）。
- **state**: `authUser`（undefined=確認中 / null=未ログイン / object）。`SET_AUTH` アクション。非永続（セッションは supabase-js が管理）。
- **ゲスト機能制限**（仕様: フレンド / ランキング参加 / 共有 / 課金 / 引き継ぎ）:
  - フレンド申請カード → 「🔒 ゲストでは利用できません + 登録する」に差し替え。
  - ランキング画面に「ゲストは参加できません（閲覧のみ）」バナー。
  - マイページに「アカウント」セクション（プロバイダ表示・アカウント登録・ログアウト）。
- **検証済み**: signup API でユーザー作成 → `profiles` 行がトリガーで自動作成されることを確認。

**Supabase ダッシュボードでの残作業**（コードからは設定不可）:

- Authentication → Sign In / Up → 「Allow anonymous sign-ins」を有効化（ゲストのサーバー同期用）
- Google / Apple OAuth プロバイダの設定（クライアントID等）
- LINE ログイン（カスタム OIDC）の設定
- Leaked password protection の有効化（推奨）

### B-3: ピース・コレクションの Supabase 同期

ゲスト制限の「アカウント登録するとデータが引き継げる」を実際に機能させるための同期実装。ゲスト（匿名認証・ローカルゲスト）は対象外、ローカルのみで完結。

- **`apps/web/src/sync.js`**（新規）:
  - `fetchRemote(userId)`: `collected_pieces` / `unlocked_tracks` / `friendships` / `encounter_cooldowns` / `profiles.coins` を取得し、ローカル state と同じ形（`collectedPieces` / `unlockedTrackIds` / `friends` / `encounterCooldowns` / `coins`）に整形。
  - `mergeStates(local, remote)`: 和集合でマージ。ピース・解放曲・フレンド（`friend_name`一致で重複排除）は和集合、クールタイムは新しい方のタイムスタンプ、コインは `Math.max`。
  - `pushRemote(userId, merged)`: マージ結果を各テーブルへ `upsert`（`onConflict` は各テーブルの複合PK: `user_id,track_id,piece_number` 等）。
  - `syncOnLogin(userId, store)`: ログイン時にリモート取得 → マージ → `MERGE_REMOTE_STATE` を dispatch → リモートへ書き戻し。失敗してもローカル動作は継続（`console.error` のみ）。
  - `syncAfterAction(userId, prevState, nextState, action)`: ログイン中の操作を都度リモートへ反映。
    - `SELECT_PIECE`: 取得ピース・新規解放曲・コイン差分・出会いクールタイムを upsert/update。
    - `ADD_FRIEND`: フレンド行を upsert（`friend_user_id` は出会いNPCのIDがUUID形式でないため `null`、`friend_name` で一致管理）。
    - `UNLOCK_TRACK`: 解放曲を upsert。
- **`apps/web/src/store.js`**: `MERGE_REMOTE_STATE` アクションを追加。マージ後の `encounterCooldowns` から `nextUnvisitedEncounter()` で `activeEncounterId` を再計算（別端末ログイン時も出会いの順番を正しく再開）。
- **`apps/web/src/app.js`**:
  - `refreshAuth()`: 非ゲストユーザーで `user.id` が前回と異なる場合のみ `syncOnLogin()` を実行（`syncedUserId` で重複防止）。
  - 追加の `store.subscribe`: 直前状態を保持し、dispatch のたびに `syncAfterAction()` を呼び出す。
- **検証済み**（テストアカウント作成 → 削除済み）:
  - 初回ログイン: ローカル133ピース・7解放曲・1フレンド・コイン2 → Supabaseへ同期完了。
  - ログイン中のピース取得・フレンド追加 → 即座に該当テーブルへ反映。
  - 別端末想定（LocalStorageクリア後に再ログイン）: リモートのデータ＋新規ローカル分がマージされ、`activeEncounterId` も正しい続きの出会いに復元。

次の候補:

- フレンド一覧・フレンド詳細画面（マイページ内・音楽でつながった履歴表示）
- デイリーミッションの実装（ホームの「0 / 5」を実機能化）
- アーティストパズル・称号タブの実装
- SwiftUI / Jetpack Compose への移植対応表を作成する。

## 2026-06-11

### C-1: フレンド一覧・フレンド詳細画面

マイページから「音楽でつながった履歴」を見られるようにする画面。`friends` 配列（`userId`/`userName`/`addedAt`/`exchangeCount`）と B-3 で同期した Supabase `friendships` テーブルを表示するだけで完結。

- **`apps/web/index.html`**: `friends-screen` / `friend-detail-screen` の `<section>` を追加。
- **`apps/web/src/store.js`**: `OPEN_FRIEND` アクション追加（`selectedFriendUserId` をセットして `friend-detail` へ遷移）。`saveState()` に `selectedFriendUserId` を追加。
- **`apps/web/src/app.js`**:
  - `npcEncounterForUserId(userId)`: `userId` から `seedData.encounters` を逆引き（出会った場所・関連曲を特定するため）。
  - `formatDate(timestamp)`: `YYYY/MM/DD` 形式の日付文字列を生成。
  - `renderMypage`: 「アカウント」と「推し曲設定」の間に「フレンド」セクションを追加（フレンド数 + 「フレンド一覧を見る」ボタン → `friends` 画面へ）。
  - `renderFriends(state)`: フレンド一覧。0人の場合は空状態メッセージ（`.notice-panel` 流用）。1人以上は `addedAt` 降順で `.track-list`/`.track-row` を流用した行（アイコン・名前・追加日・出会った場所・交換回数）。各行に `data-open-friend="${userId}"`。
  - `renderFriendDetail(state)`: フレンド詳細。ヘッダー（`.home-header`/`.avatar`/`.home-user`）、`.stat-grid`（フレンド歴・交換回数・出会った場所）、出会ったNPCの `encounter.candidates` から `.song-grid`（音楽でつながった曲・未解放曲はマスク表示）。
  - クリックハンドラに `[data-open-friend]` → `OPEN_FRIEND` dispatch を追加。
- 検証: LocalStorage に `friends` を1件投入 → マイページ「フレンド 1人」表示 → 一覧で田中ゆきの行（大学・交換1回・追加日）表示 → 詳細で フレンド歴4日／交換回数1回／出会った場所「大学」と、出会ったNPC（encounter_today_001）の5曲（Pretenderは解放済みのため曲名表示、他4曲は「未解放メロディ」表示）を確認。

### C-2: デイリーミッションの実装

ホームの「0 / 5」表示を実機能化。「ピースを5個獲得」を条件に進捗管理し、達成時にメロディコイン+10を付与。

- **`apps/web/src/data.js`**:
  - `todayKey()`（`YYYY-MM-DD`）を `formatNumber` の直後にエクスポート追加（`store.js`/`app.js` 共通の日付キー判定に使用、`app.js` 内のローカル定義は削除）。
  - `seedData.mission` を `{ label: "デイリー", current: 0, target: 5 }` → `{ label: "デイリー", target: 5, rewardCoins: 10 }` に変更。
  - `initialAppState()` に `dailyMission: { date: todayKey(), progress: 0, claimed: false }` と `selectedFriendUserId: null` を追加。
- **`apps/web/src/store.js`**:
  - `getDailyMissionProgress(state)`: 日付が変わっていれば `{date, progress:0, claimed:false}` にリセットして返す。
  - `SELECT_PIECE`: 新規ピース獲得時に `dailyMission.progress` を+1（上限5）。`progress >= target` かつ未達成なら `claimed:true` + コイン+10、トーストに `🎉 デイリーミッション達成！メロディコイン +10` を追記（複数行）。
  - `saveState()` に `dailyMission` を追加。
- **`apps/web/src/styles.css`**: `.toast` を複数行メッセージ対応（`white-space:pre-line; text-align:center`）に変更。
- **`apps/web/src/app.js`**: `renderHome` でミッションパネルに実進捗（`n / 5`・進行バー・説明文）を表示。達成時は「🎉 達成済み！メロディコイン +10 を獲得しました」、未達成時は「あとnピース獲得で達成」のような案内を表示。
- 検証: ピースを5個（新規）獲得 → `dailyMission` が `{progress:5, claimed:true}` に更新 → コインが規定通り加算（新規ピース+1×5 + 達成ボーナス+10 = +15）→ 複数行トースト表示 → ホームのミッションパネルが「5/5・🎉 達成済み！メロディコイン +10 を獲得しました」表示に切り替わることを確認。コンソールエラーなし。

次の候補:

- アーティストパズル・称号タブの実装
- フレンドの「交換回数」を実際の交換イベント発生時にインクリメントする（現状は `ADD_FRIEND` 時に固定で1）
- SwiftUI / Jetpack Compose への移植対応表を作成する。

### C-3: アーティストパズル・称号タブの実機能化

コレクション画面の「アーティスト」タブはシード固定値（YOASOBI 1組のみ・12/18固定）、「称号」タブはプレースホルダーのみだったのを実データ連動に変更。

- **`apps/web/src/data.js`**:
  - `seedData.artists`（YOASOBI 1件・`completedTrackPuzzles` 等の固定値）を削除。
  - `seedData.titles` を追加: 称号8種の定義（`id`/`icon`/`name`/`description`/`type`/`target`）。
    - type: `puzzles`（完成曲数: 1曲/3曲/全曲）・`artists`（全曲完成アーティスト1組）・`friends`（フレンド1人/3人）・`unlocks`（曲名解放5曲）・`mission`（デイリーミッション達成）。`target: "all"` は全曲数を表す。
- **`apps/web/src/app.js`**:
  - `artistGroups(state)`: `seedData.tracks` を `artistId` でグループ化し、完成曲数を `collectedPieces` から実計算（アーティストマスタ不要に）。
  - `titleProgress(state, title)`: 称号の `current` / `target` / `unlocked` を state から算出。
  - `computeCollection`: ホームの「アーティスト n / m」を `artistGroups` ベースの実計算に変更（0/1 固定 → 実アーティスト8組）。
  - アーティストタブ: 全アーティストをカード表示し、完成数・進捗バーを実計算値で描画。
  - 称号タブ: 「n / 8 獲得」ヘッダー + 称号カードリスト。獲得済みは紫グラデ枠 + 「獲得済み」、未獲得はグレースケールアイコン + 進捗バー + `current / target` 表示。
  - 検索ローカルフォールバック: `seedData.artists` 参照（YOASOBI 以外 `""` になっていた）を `track.artistName` 直接参照に修正。
- 検証: アーティストタブに8組全員が実進捗（髭男 0/2・Niziu 0/1 等）で表示。称号タブは現在の state（フレンド1人・解放7曲・ミッション達成済み）で「3 / 8 獲得」（はじめてのフレンド・名曲ハンター・今日のがんばり屋）が正しく解放表示されることを確認。

### C-4: フレンド交換回数の実イベント連動

- **`apps/web/src/store.js`**: `SELECT_PIECE` で出会い相手が既フレンドの場合、該当フレンドの `exchangeCount` を+1（未フレンドなら従来通り `pendingFriendAdd` をセット）。
- **`apps/web/src/sync.js`**: `syncAfterAction` の `SELECT_PIECE` ブランチに、`exchangeCount` が増えたフレンドの `friendships.exchange_count` をリモート更新する処理を追加。
- 検証: 既フレンド（田中ゆき）の出会いクールタイムを解除して再交換 → `exchangeCount` が 1→2 にインクリメントされることを確認。コンソールエラーなし。

### C-5: SwiftUI / Jetpack Compose 移植対応表

- **`docs/native-porting-map.md`**（新規）: Webプロトタイプの構造ごとに SwiftUI / Jetpack Compose での実現方法を対応表化。
  - アーキテクチャ（store.js → @Observable/TCA・ViewModel+StateFlow、LocalStorage → UserDefaults/DataStore）
  - 画面対応（10画面 + 下部ナビ → TabView/NavigationStack・Scaffold/Navigation Compose）
  - コンポーネント・演出（モーダル・トースト・パーティクル・モザイク・波形アニメーション等）
  - 状態・ロジック（アクション単位の移植注意点。reduce 純粋関数はほぼ機械的に移植可能）
  - 外部連携（YouTube プレイヤー規約注意・supabase-swift/kt・すれちがい通信は MultipeerConnectivity / Nearby Connections）
  - 移植優先順位の目安（データ層 → コア画面 → 同期 → 演出 → すれちがい本実装）

### C-6: npm scripts の現行コード対象化・旧並行コピー削除

`npm run check` / `test:store` がルートの古い `src/` 並行コピー（v1キー・旧アクション体系 `SELECT_CANDIDATE` 等）を検証していて、現行コード（`apps/web/src/`）のテストになっていなかった問題を修正。

- **`package.json`**:
  - `serve`: `python3 -m http.server 5173`（ルートの旧 index.html を配信）→ `python3 apps/web/serve.py`（現行の開発サーバー・port 5174）に変更。
  - `check`: 対象を `apps/web/src/` の全JS（app/data/store/sync/supabase/api）に変更。
  - `test:store`: インラインの `-e` スクリプト → `node scripts/test-store.mjs` に変更。
- **`scripts/test-store.mjs`**（新規）: 現行の store.js（v2キー・`SELECT_PUZZLE`/`SELECT_PIECE` 体系）に対するテスト。
  - ピース取得 → ピース・コイン+1・デイリーミッション進捗・クールタイムの永続化を検証。
  - 重複ピース取得でミッション進捗が増えないことを検証。
  - `ADD_FRIEND` → 既フレンドとの再交換で `exchangeCount` が 1→2 になること（C-4）を検証。
  - `UNLOCK_TRACK` の永続化を検証。
- **削除**: ルートの `src/`（4ファイル）と `index.html`（旧6画面レイアウト）。どこからも参照されていないことを確認済み（git管理下のため復元可能）。

### D-1: すれちがい出会いの6時間リフレッシュ実装

`nextUnvisitedEncounter()` が `!cooldowns[id]`（未訪問か）しか見ておらず、5件全てにクールタイムが付くと「次の出会い」が永久に出現しない（コアループが停止する）問題を修正。

- **`apps/web/src/data.js`**: `COOLDOWN_MS = 6 * 60 * 60 * 1000`（6時間）と `OSHI_LIMIT = 3` を先頭付近にエクスポート追加（`app.js` 内に重複していた `COOLDOWN_MS` 定義を一本化）。
- **`apps/web/src/store.js`**:
  - `isAvailable(cooldowns, id)`: 未訪問 または `Date.now() - cooldowns[id] >= COOLDOWN_MS` で `true`。
  - `nextUnvisitedEncounter()` を `nextAvailableEncounter(cooldowns)` に置き換え。`seedData.encounterOrder` から `isAvailable` を満たす最初の id を返す（無ければ `null`）。
  - `SELECT_PIECE` / `MERGE_REMOTE_STATE` の自動前進ロジックを `nextAvailableEncounter` 呼び出しに変更。
- **`apps/web/src/app.js`**:
  - ローカル `COOLDOWN_MS` 定義を削除し `data.js` からインポート。
  - `nextEncounterButton(state)`: 「クールタイム明け」も次の出会いとして検出するよう書き換え。全件クールタイム中の場合は「🎉 今日の出会いを全て確認しました／次の出会いまであと ◯時間◯分」を表示。
  - 「今日の出会い一覧」: `clickable = !isLocked`（未来の未訪問のみロック）に変更。クールタイム中の済み出会いは「済 · あと◯時間◯分」バッジ、クールタイム明けは「受信可」バッジ（`var(--mint)` ・太字）で表示し、タップで `SWITCH_ENCOUNTER` 可能に。
- **`scripts/test-store.mjs`**: 独立ストアで encounter_today_001 を消化 → encounter_today_002 へ自動前進 → `encounter_today_001` のクールタイムをLocalStorage上で6時間以上前に書き換え（期限切れをシミュレート）→ ストア再生成 → encounter_today_002 を消化すると `activeEncounterId` が `encounter_today_001` に戻る（再受信可能）ことを検証。
- 検証: `npm run test:store` で上記アサーションが通ることを確認。ブラウザでも encounter_today_001 を消化（→ today_002 へ自動前進）→ クールタイムを手動で期限切れに書き換えてリロード → メロディ画面で「1人目（田中ゆき）」が「受信可」（mint・太字）でクリック可能、「2人目（佐藤けんじ）」が「→ 今ここ」、3〜5人目は「🔒 順番待ち」のままであることをスクリーンショットで確認。

### D-2: 推し曲設定の実装

マイページ「推し曲設定（0/3曲）」とコレクション>推し曲タブが、いずれも見た目だけのプレースホルダーで未機能だったのを実装。

- **`apps/web/src/data.js`**: `OSHI_LIMIT = 3`（D-1と合わせて追加）。`initialAppState()` に `oshiTrackIds: []` を追加。
- **`apps/web/src/store.js`**:
  - `saveState()` に `oshiTrackIds` を追加（LocalStorageのみで完結。`previewPlays`/`dailyMission` と同様にSupabase同期対象外）。
  - `TOGGLE_OSHI_TRACK` アクション: 既に推し曲なら解除。上限（`OSHI_LIMIT`=3）到達時は追加せずトースト「推し曲は3曲まで設定できます」。それ以外は追加してトースト「◯◯ を推し曲に設定しました」。
- **`apps/web/src/app.js`**:
  - マイページ「推し曲設定」: 選択済みの曲をタイル表示（✕ボタンで `TOGGLE_OSHI_TRACK` → 解除）。`state.unlockedTrackIds` から選択可能な曲をチップ一覧で表示し、タップで追加。
  - コレクション>推し曲タブ: `state.oshiTrackIds` があれば実曲のタイル一覧を表示。0件の場合は従来のプレースホルダー/CTAのまま。
  - クリックハンドラに `[data-toggle-oshi]` → `TOGGLE_OSHI_TRACK` dispatch を追加。
- **`scripts/test-store.mjs`**: 解放済み曲から3曲を `TOGGLE_OSHI_TRACK` で追加（`oshiTrackIds.length === OSHI_LIMIT` を確認）。4曲目は追加されないこと、1曲を再トグルすると解除されることを検証。
- 検証: `npm run test:store` で上記アサーションが通ることを確認。ブラウザで解放済みの曲から3曲（Pretender / Sunset Drive / 唱）を追加 → マイページの推し曲セクションとコレクション>推し曲タブの両方に反映されることをスクリーンショットで確認。

### E-1: 称号獲得時のトースト・演出

称号タブで条件を満たしても獲得瞬間の通知がなかったのを、トースト + 専用オーバーレイで演出するように実装。

- **`apps/web/src/store.js`**:
  - `artistGroups` / `titleProgress` を app.js から store.js へ移動してエクスポート（app.js はインポートに変更）。称号判定をストア側で行えるようにするため。
  - `unlockedTitleIds(state)`: 獲得済み称号IDの一覧を算出。
  - `dispatch()` 内でアクション適用の前後を比較し、新規に達成した称号を検知 → `pendingTitleCelebrations` キューへ追加 + トーストに「🏆 称号「◯◯」を獲得！」を追記（diff方式なので、ロード時点で既に獲得済みの称号では発火しない）。
  - `DISMISS_TITLE_CELEBRATION` アクション: キュー先頭の1件を消化。
- **`apps/web/src/data.js`**: `initialAppState()` に `pendingTitleCelebrations: []` を追加（非永続）。
- **`apps/web/index.html`**: `<div id="title-celebration-root">` を追加。
- **`apps/web/src/app.js`**: `renderTitleCelebration(state)` — 「TITLE UNLOCKED」ヘッダー・称号アイコン（揺れアニメーション）・称号名・達成条件・「やったね！」ボタンのフルスクリーンオーバーレイ（z-index 310）。パズル完成演出の表示中はそれを閉じた後に表示。複数同時獲得時は1件ずつ順に表示（「ほかに n 件」の注記つき）。
- 検証: パズル完成 → 完成演出を閉じると称号演出が表示され、「やったね！」で閉じることをスクリーンショットで確認。トーストにも称号獲得行が追記される。

### E-2: 経験値・レベルアップの実装

「完成報酬 経験値×50」とマイページの Lv 表示が実態と連動していなかったのを実装。

- **`apps/web/src/data.js`**:
  - `PIECE_EXP = 5`（新規ピース1枚あたりの獲得経験値）と `levelFromExp(exp)`（Lv.L → L+1 に L×100 exp 必要。`{level, current, next}` を返す）をエクスポート追加。
  - `initialAppState()` に `exp: 0` を追加。`seedData.user` の固定値 `level` / `levelProgress` は削除（state から算出）。
- **`apps/web/src/store.js`**: `SELECT_PIECE` で新規ピース獲得時に `+PIECE_EXP`、パズル完成時はさらに `+track.rewardExp`。レベルが上がった場合はトーストに「⬆️ レベルアップ！ Lv.n になりました」を追記。`saveState()` に `exp` を追加（LocalStorageのみ）。
- **`apps/web/src/app.js`**: ホーム・マイページのレベル表示と進捗バーを `levelFromExp(state.exp)` ベースの実計算に変更。マイページに「次のレベルまで あと◯ EXP」を追加。パズル完成演出に「⭐ +50 EXP」バッジを追加。
- **`scripts/test-store.mjs`**: `levelFromExp` の換算（0→Lv.1 / 100→Lv.2 / 300→Lv.3）、完成時の `exp = PIECE_EXP + rewardExp` 加算と永続化、レベルアップ・称号獲得のトースト文言、`DISMISS_TITLE_CELEBRATION` の消化、`ADD_FRIEND` での称号検知を検証。
- 検証: `npm run test:store` 通過。ブラウザで pretender 23枚 + exp95 の状態から最後の1枚を取得 → exp150・Lv.2 表示・複数行トースト（完成/レベルアップ/称号）を確認。

### E-3: ランキング画面の実データ連動

4タブすべてが同じ固定ダミー5曲を表示していたのを、ユーザーランキング（集めたピース数）に変更し自分の順位を実データから算出。

- **`apps/web/src/app.js`**: `renderRanking` を書き換え。
  - 自分の行: `state.collectedPieces` の合計枚数を指標に「Mia（あなた）」をハイライト表示（紫背景・順位はソートで実算出）。ヘッダーに「あなたは◯位」。
  - 今日タブ: すれちがいNPC5人（出会いデータから生成・固定枚数 `NPC_PIECES`）+ 自分。
  - 近く/全国タブ: NPC + エリア/全国のダミー参加者 + 自分。
  - 友達タブ: `state.friends` の実データから行を生成（交換回数をサブテキスト表示）。フレンド0人なら空状態（「まだフレンドがいません」+ 出会いへの導線）。
- 検証: 今日タブで「あなたは6位・24枚」（シード状態の実枚数）がハイライト表示、友達タブはフレンド0人で空状態 → フレンド追加後は「1 田中ゆき 交換2回 96枚 / 2 Mia（あなた）24枚」になることを確認。

### F-1: 完成報酬コインの実付与

パズル画面の「完成報酬 メロディコイン ×100」が表示のみで、完成時に通常の+1コインしか付与されていなかったのを実付与に変更。

- **`apps/web/src/store.js`**: `SELECT_PIECE` の完成判定（`justCompleted`）時に `completionCoins = track.rewardCoins`（100枚）をコイン加算へ追加。トーストに「🪙 完成報酬 メロディコイン +100」行を追記。
- **`apps/web/src/app.js`**: パズル完成演出のコインバッジを「+1 コイン」固定から「+${rewardCoins + 1} コイン」（新規ピース分+完成報酬）に変更。
- Supabase同期は既存の `coins` 差分同期（`sync.js` が絶対値を update）でそのまま反映されるため変更不要。
- 検証: pretender 23枚から最後の1枚を取得 → コイン 0 → 101、トースト・完成演出バッジ（🪙 +101 コイン）を確認。`test-store.mjs` に `coins === 1 + rewardCoins` のアサーションを追加。

### F-2: プレミアムプラン導線の実装

マイページ設定メニューの「プレミアムプラン」（表示のみ）を、専用画面 + 模擬加入フロー + 実際の特典反映つきで実装。

- **`apps/web/src/data.js`**: `OSHI_LIMIT_PREMIUM = 5`・`oshiLimit(state)`（プランに応じた推し曲上限）・`PREMIUM_PRICE_LABEL = "¥480 / 月"` をエクスポート。`initialAppState()` に `premium: false` を追加。
- **`apps/web/src/store.js`**:
  - `SET_PREMIUM` アクション: 加入/解約のトグル。解約時は推し曲を無料枠（3曲）まで先頭から自動調整。`saveState()` に `premium` を追加。
  - `TOGGLE_OSHI_TRACK` の上限を `oshiLimit(state)` に変更（無料3曲/プレミアム5曲）。
  - `COMPLETE_AD` のトーストにプレミアム時「⭐ プレミアム特典：広告なしで解放」を前置。
- **`apps/web/index.html` + `apps/web/src/app.js`**:
  - `premium` 画面（新規）: プラン名・価格・「プロトタイプのため決済は行われません」注記・特典3つ（広告非表示/推し曲5曲/エリアランキング）・加入ボタン（模擬決済）。加入中は「解約する」ボタン + 解約時の推し曲自動調整の説明。
  - マイページ: 設定メニューの「プレミアムプラン」行を `data-target="premium"` でクリック可能に（加入中は「⭐ 加入中」表示）。ヘッダーのユーザー名横に「⭐ プレミアム」バッジ。推し曲セクションの上限表示・チップ表示条件を `oshiLimit(state)` 連動に変更（無料上限到達時はプレミアムへのリンク）。
  - ランキング「近く」タブ: プレミアム加入中はアップセルバナーを非表示にし「⭐ プレミアム特典でエリアランキングを閲覧できます」を表示。未加入時の「詳細」ボタンは premium 画面へ遷移。
  - 広告ヒント: プレミアム加入中は `[data-ad]` クリックで確認モーダルを挟まず `COMPLETE_AD` を直接 dispatch（広告非表示の実体験）。
- 検証: 加入 → マイページにバッジ・推し曲 0/5 表示・5曲まで追加可能・ランキング近くタブの表示切り替え・ヒント解放がモーダルなしで即時実行（トーストにプレミアム特典表記）を確認。解約 → 推し曲が5曲 → 3曲に自動調整されることを確認。`test-store.mjs` にプレミアム上限・解約時トリムのアサーションを追加。

### F-3: 今日のメロディプレイリスト画面の実装

`seedData.dailyPlaylist`（ホームの「今日のメロディ」ヒーローパネルの元データ）を一覧表示する画面を実装。

- **`apps/web/index.html`**: `playlist-screen` セクションを追加。
- **`apps/web/src/app.js`**:
  - `renderPlaylist(state)`: ヘッダー（タイトル・「2026年6月4日・大学で12人と音楽でつながりました」サブタイトル＝出会いデータから生成）。プレイリスト4曲の行（アート・曲名（未解放はマスク）・アーティスト・所持ピース進捗バー・n/24 または「完成！」・▶試聴ボタン）。行タップで曲詳細（`data-open-track`）へ。
  - ホームのヒーローパネルを `data-target="playlist"` でクリック可能に（「プレイリストを見る ›」の案内を追記）。
  - クリックハンドラの `[data-preview-track]` 判定を `[data-open-track]` より先頭に移動（行内の試聴ボタンが行タップに吸われる問題の予防）。
- 検証: ホームのヒーローパネル → プレイリスト画面遷移、4曲（Sunset Drive / ブルーベリー・ナイツ / Magic Hour / ハルジオン）の進捗・試聴ボタン表示をスクリーンショットで確認。

## 2026-06-12

### G-1: ショップ画面の実装

マイページの「ショップ」（表示のみ）を実装し、メロディコインに使い道を持たせた。

- **`apps/web/src/data.js`**: `SHOP_ITEMS`（5商品）をエクスポート。`initialAppState()` に `hintTickets: 0` / `ownedDecorations: []` / `equippedDecoration: null` を追加。
  - 🎟️ ヒントチケット（15コイン・type: ticket）: 広告なしでヒントを1回解放
  - 🎲 ランダムピース（20コイン・type: piece）: 未完成パズルからランダム1ピース獲得
  - 🎩 シルクハット / 🎀 リボン（各50コイン）・👑 クラウン（100コイン）（type: decoration・買い切り）
- **`apps/web/src/store.js`**:
  - `BUY_SHOP_ITEM`: コイン不足は拒否（トースト）。チケット→所持数+1、装飾→購入と同時に自動装備（重複購入拒否）、ランダムピース→未完成トラックからランダム選択して1ピース追加。ピース獲得は通常取得と同様に経験値+5・デイリーミッション進行・完成判定（完成報酬コイン・曲名解放・完成演出・称号検知）まで連動。
  - `EQUIP_DECORATION`: 装備のトグル（同じ装飾を再選択で外す）。
  - `COMPLETE_AD` に `viaTicket` を追加: チケットを1枚消費してヒント解放（トーストに残数表示）。解放手段の優先順は プレミアム > チケット > 広告モーダル（`app.js` の `[data-ad]` ハンドラで分岐）。
  - `saveState()` に `hintTickets` / `ownedDecorations` / `equippedDecoration` を追加。
- **`apps/web/src/app.js` + `index.html`**:
  - `shop` 画面（新規）: 所持コイン・アイテム2種（チケットは所持枚数表示）・アバター装飾3種（購入済みは「装備する/外す」、コイン不足は購入ボタンを無効化）。
  - `avatarWithDeco(state)`: 装備中の装飾絵文字をアバター右上にオーバーレイ表示（ホーム・マイページのヘッダーで使用）。
  - マイページ設定メニューの「ショップ」行をクリック可能に（チケット所持時は 🎟️×n を表示）。
  - 未解放メロディ画面: チケット所持時（非プレミアム）は「🎟️ ヒントチケット n枚所持 — 広告なしで解放されます」の案内を表示。
- 検証: チケット購入（コイン-15・所持1枚）→ ランダムピース購入（ピース+1・ミッション進行）→ シルクハット購入（自動装備・ヘッダーに🎩表示）→ コイン不足のクラウンは購入ボタン無効 → チケットでヒント解放（モーダルなし・残0枚トースト）を一通り確認。

### G-2: 通知設定画面の実装

マイページの「通知設定」（表示のみ）を設定画面として実装。

- **`apps/web/src/data.js`**: `initialAppState()` に `notificationSettings: { immediate: true, digest: false, digestTime: "20:00", encounter: true, mission: true }` を追加。
- **`apps/web/src/store.js`**: `TOGGLE_NOTIFICATION`（キー単位トグル）・`SET_DIGEST_TIME`（まとめ通知の時間帯）。`saveState()` で永続化。
- **`apps/web/src/app.js` + `index.html`**: `notify-settings` 画面（新規）: 即時通知・まとめ通知（ONのとき 09:00/12:00/20:00 の時間帯チップを表示）・すれちがい通知・ミッション達成通知のスイッチUI（CSSトグル）。「プロトタイプのため実際の通知は送信されません」の注記つき。マイページ設定メニューから遷移。
- 検証: まとめ通知ON → 時間帯チップ出現 → 09:00 選択 → LocalStorage に `{digest: true, digestTime: "09:00"}` が永続化されることを確認。

### G-3: 音楽サービス連携の模擬実装

マイページの「連携する」ボタン（未機能）を模擬連携として実装。

- **`apps/web/src/data.js`**: `initialAppState()` に `linkedServices: { spotify: false, appleMusic: false, youtubeMusic: false }` を追加。
- **`apps/web/src/store.js`**: `TOGGLE_SERVICE_LINK`: 連携のトグル。連携時「🎵 ◯◯ と連携しました（プロトタイプ・模擬連携）」、解除時「◯◯ との連携を解除しました」のトースト。`saveState()` で永続化。
- **`apps/web/src/app.js`**: マイページの連携セクションを state 連動に変更。連携中はサービス名に「✓ 連携中」バッジ + ボタンが「解除」（secondary）に切り替わる。
- 検証: Spotify 連携 → ✓連携中表示・トースト・LocalStorage 永続化 → 解除でOFFに戻ることを確認。

- **`scripts/test-store.mjs`**: G-1〜G-3のアサーションを追加（チケット購入のコイン減・永続化、チケット消費でのヒント解放、ランダムピースの+1とミッション進行、装飾の自動装備・重複購入拒否・付け外し、コイン不足の購入拒否、通知設定・サービス連携の永続化）。`npm run check` / `npm run test:store` 通過。

### H-1: バックグラウンド検知の設定画面

マイページ設定メニューで唯一未機能だった「バックグラウンド検知」を設定画面として実装。

- **`apps/web/src/data.js`**: `initialAppState()` に `backgroundScan: { enabled: true, mode: "balanced", nightPause: false }` を追加。
- **`apps/web/src/store.js`**: `TOGGLE_BG_SCAN`（enabled / nightPause のトグル）・`SET_BG_SCAN_MODE`（powersave / balanced / performance）。`saveState()` で永続化。
- **`apps/web/src/app.js` + `index.html`**: `bg-settings` 画面（新規） — マスタートグル・スキャン頻度のラジオ選択（省電力=約15分 / 標準=約5分 / 高頻度=約1分・バッテリー消費の目安つき。OFF時は非表示）・「夜間は検知しない（22時〜翌6時）」トグル。設定メニューの行にも現在の状態（「オン · 省電力スキャン」等）を表示。通知設定と共通のスイッチUIを `switchToggle` / `settingRow` ヘルパーとして共通化。
- 検証: 省電力モード選択 + 夜間停止ON → LocalStorage に `{enabled: true, mode: "powersave", nightPause: true}` が永続化、メニューの行が「オン · 省電力スキャン」表示に切り替わることを確認。

### H-2: 称号の常設リワード

称号を獲得しても表示が変わるだけだったのを、獲得時にコイン/EXPボーナスを付与するように変更。

- **`apps/web/src/data.js`**: `seedData.titles` の全8称号に `rewardCoins` / `rewardExp` を追加（はじめてのひとかけら 30/30・メロディコレクター 50/50・パズルマエストロ 200/200・推しマスター 100/100・はじめてのフレンド 30/30・音楽の輪 50/50・名曲ハンター 50/50・今日のがんばり屋 20/20）。
- **`apps/web/src/store.js`**: `dispatch()` の称号検知ブロックで、獲得した称号の報酬コイン/EXPを合算して付与。EXP加算によるレベルアップも判定してトーストに追記。トーストは「🏆 称号「◯◯」を獲得！（🪙+30 ⭐+30 EXP）」形式に。
- **`apps/web/src/app.js`**: 称号獲得演出オーバーレイに報酬バッジ（🪙 +n コイン / ⭐ +n EXP）を追加。コレクション>称号タブの各称号に「獲得報酬: 🪙n · ⭐n EXP」を表示。
- 検証: パズル完成 → コイン 0 → 131（ピース1 + 完成報酬100 + 称号30）・EXP 95 → 180（+5+50+30）が一致。演出オーバーレイのバッジと称号タブの報酬表示も確認。テストの既存アサーションを称号リワード込みの期待値に更新。

### H-3: 推し曲のすれちがい連動

推し曲を設定しても表示されるだけだったのを、すれちがい（ピース交換）時に自分の推し曲が相手に届く演出として実装。

- **`apps/web/src/data.js`**: `initialAppState()` に `oshiDeliveries: {}`（ユーザーIDごとの配達累計）を追加。
- **`apps/web/src/store.js`**: `SELECT_PIECE` で推し曲が設定されていれば、出会い相手への配達回数に応じて推し曲を順番に1曲選び（ローテーション）、`oshiDeliveries[userId]` をインクリメント。トーストに「🎵 あなたの推し曲「◯◯」を ◯◯さんに届けました」を追記。`saveState()` で永続化。
- **`apps/web/src/app.js`**:
  - マイページ推し曲セクション: 説明文を「すれちがいの相手にあなたの推し曲が届きます」に変更し、配達があれば「🎵 これまでに n回 届けました」を表示。
  - フレンド詳細画面: 配達実績のある相手に「🎵 あなたの推し曲をこれまでに n回 届けました」を表示。
- 検証: 推し曲「夜に駆ける」を設定してピース交換 → トーストに配達演出・`oshiDeliveries: {user_tanaka_yuki: 1}` が永続化・マイページに「これまでに 1回 届けました」表示を確認。

- **`scripts/test-store.mjs`**: H-1〜H-3のアサーション追加（バックグラウンド検知設定の永続化、称号リワード込みのコイン/EXP期待値への更新、推し曲配達の記録・トースト・永続化）。`npm run check` / `npm run test:store` 通過。

次の候補:

- ホームの通知バッジ・「今日n件のメロディ」と通知設定の連動（即時通知OFF時はバナーを抑制する等）
- アーティストページ（コレクション>アーティストのカードから詳細ページへ遷移する導線が未実装）
- 設定メニュー残り3行（ヘルプ・利用規約・通知以外のショップ内通貨追加など）の実装

## 2026-06-17

### I-1: ホームの通知バナーと通知設定の連動

ホームの「今日n件のメロディが届いています」バナーが通知設定（G-2実装済み）と無関係だったのを連動させた。

- **`apps/web/src/app.js`**: `renderHome` の notice-panel 表示条件に `state.notificationSettings?.immediate !== false` を追加。
  - 即時通知 ON（デフォルト）: 「NEW」バッジ付きのフル強調バナー（紫「確認する」ボタン）
  - 即時通知 OFF: 🔕アイコン・opacity:0.6 の控えめバナーに切り替わり「即時通知オフ — まとめ通知でお知らせします」サブテキストを表示。「確認する」ボタンは secondary スタイルに変更。メロディは引き続きタップで確認できる。
- 検証: localStorage で `immediate: false` にセットして再ロード → バナーが🔕・半透明表示に変化することをブラウザで確認。`immediate: true` に戻すと通常バナーに復帰。

### I-2: アーティスト詳細ページの実装

コレクション > アーティストタブのアーティストカードをタップしても何も起こらなかった（詳細画面未実装）のを、アーティスト個別の曲パズル一覧ページとして実装。

- **`apps/web/src/data.js`**: `initialAppState()` に `selectedArtistId: null` を追加。
- **`apps/web/src/store.js`**:
  - `OPEN_ARTIST` アクション: `selectedArtistId` をセットして `activeScreen = "artist-detail"` へ遷移。`saveState()` に `selectedArtistId` を追加。
- **`apps/web/index.html`**: `artist-detail-screen` セクションを追加。
- **`apps/web/src/app.js`**:
  - `renderArtistDetail(state)`: ヘッダー（アーティスト名・「曲パズル n/m 完成」）、アーティストプロフィール（アバター・名前・進捗バー）、「曲パズル一覧」（全曲をリスト表示・アートブロック・タイトル/未解放マスク・進捗バー・n/24 または「完成!」）。各曲行は `data-open-track` でパズル/未解放画面へ遷移可能。戻るボタンは `data-back="collection"` でアーティストタブに戻る（`collectionTab` state が "artists" のまま保持されるため自然に戻る）。
  - `renderCollection` アーティストタブ: 各アーティストブロックのヘッダー行を `display:flex;justify-content:space-between` に変更し、アーティスト名右に「詳細 ›」ボタン（`data-open-artist="${artist.id}"`）を追加。
  - クリックハンドラに `[data-open-artist]` を追加（`OPEN_ARTIST` アクションを dispatch）。
  - `renderAll()` に `renderArtistDetail(s)` を追加。
- 検証: Official髭男dism の「詳細 ›」→ アーティスト詳細画面（Pretender 12/24・Magic Hour 22/24）が表示。戻るボタンでアーティストタブに正常復帰することをブラウザで確認。`npm run check` / `npm run test:store` 通過。

次の候補:

- 設定メニュー残り行（ヘルプ・利用規約・アプリについて等の静的テキスト画面）の実装
- コレクション > アーティスト詳細から推し曲設定へのショートカット（「この曲を推し曲に設定」ボタンをアーティスト詳細の各曲行に追加）
- ホームの「最近届いた曲」セクションをすれちがい履歴と連動（ピース取得した曲が自動追加される）

## 2026-06-23

### ネイティブ（iOS）UIリニューアル・YouTubeサムネイルパズル

ネイティブiOSアプリ（`apps/ios/`, SwiftUI）の表示まわりを設計書（Obsidian: `StreetMelody_パズル生成仕組み設計書` / `StreetMelody_UI設計・必要素材リスト`）準拠で一通り整備した。

**1. ライトモード全面化**
- `StreetMelodyApp.swift` に `.preferredColorScheme(.light)`。全画面のダーク配色（`0f0a20` 等）をライト配色へ変換（背景 `F5F0FF` / カード `FFFFFF` / 枠 `E0D8F7` / ミュート `EDE8FF` / アクセント `7248E0` / 副文字 `7B6F8A`）。完成演出オーバーレイのみ意図的にダーク維持。

**2. 画面全体表示（黒帯解消）**
- 起動画面未設定によりレガシー互換モードでレターボックス（上下黒帯）になっていた問題を、`Info.plist` / `project.yml` に `UILaunchScreen` ＋ `UIApplicationSceneManifest` を追加して解消。
- `ContentView` の `BottomNavBar` を下げて（`.padding(.bottom, 14)→4`）ホームインジケーター付近に配置。

**3. YouTubeサムネイル＋6×4パズル（設計書準拠）**
- `Track` に `youtubeVideoId`／`youtubeThumbnailURL`（`i.ytimg.com/vi/{id}/mqdefault.jpg`。架空曲 `official-*` は除外）。
- `ArtBlockView`: サムネイル表示＋未解放はモザイク（`mosaic`）。`ArtBlockView(track:)` で解放=鮮明/未解放=モザイクを自動出し分け。
- `PuzzlePiecesView`（新規）: 16:9を6×4に分割し、所持ピースだけサムネイルを見せ未所持は lockedピース（`E3DAF5`）。`revealAll`/`blur` でフル表示/モザイク/ピース確認を切替。`PuzzleView`・`MysteryView`・メロディカルーセルに適用。
- `PieceSelectView`: 所持ピースはサムネイルの該当領域を切り出し表示、取得可能ピースは紫ハイライト＋タップ取得、取得不可は lockedピース（設計書 §8.2）。
- `CachedThumbnail`（新規）: `NSCache`＋`@State`＋タイムアウト付き専用`URLSession`で画像をキャッシュ。`Color.clear`基準＋`.overlay`画像で、コンテナ形状（正方形=1:1クロップ / 16:9）に追従。
- 既知の落とし穴対応: ① `img.youtube.com`はシミュレータのQUICでスタールするため`i.ytimg.com`へ。② キャッシュ判定の`if image == nil`ガードでビュー再利用時に前トラックの画像が残る取り違えを修正（常に更新）。③ ホーム「最近届いた曲」は`Dictionary.values`の不定順を解放優先＋id順の安定ソートに。

**Android（`apps/android/`）**: `Track.youtubeThumbnailUrl` のホスト/解像度をiOSと統一、`ArtBlock`にCoilでサムネイル表示を追加。ただしAndroidは現状Home画面のみのスキャフォルドで、当環境に `gradlew`/Android SDK が無くビルド検証は未実施。

検証: iPhone 16 Proシミュレータで全タブ・パズル/未解放/ピース選択/カルーセルを目視確認。`xcodebuild` は `BUILD SUCCEEDED`。

次の候補:
- Androidネイティブの各画面（メロディ/パズル/コレクション/マイページ）実装とパズル6×4リビールの移植
- iOS: パズル完成演出オーバーレイのライト/サムネイル対応
- ピース選択でピース取得後のフレンド申請カード・「次の出会いへ」導線（Web版相当）の移植

### ピース選択のサムネイル化／取得後導線／完成演出／Androidパズル

設計書の積み残し（ピース選択のサムネイルピース・取得後のフレンド/次の出会い導線）と、Android への 6×4 リビール移植を実施。

**iOS**
- `PieceSelectView`: 抽象セルを廃止し、所持ピースはサムネイルの該当領域を offset+clip で切り出して表示。取得可能＝紫ハイライト＋番号（タップ取得）、取得不可＝lockedピース（設計書 §8.2）。
- 取得後導線（Web版相当）を新規 `PostCollectSection`（フレンド申請カード＋「n人目の出会いへ」）として実装し、`MysteryView`/`PuzzleView` 末尾に配置。`AppViewModel` に `pendingFriendAdd`/`showNextEncounterPrompt`・`confirmFriendAdd`/`dismissFriendPrompt`/`goToNextEncounter`/`clearCollectPrompts` を追加。`collectPiece` で既存フレンドは交換回数+1、未フレンドはフレンド申請カードを提示。`goBack`/タブ切替で導線をクリア。
- `PuzzleCompleteOverlay`: 完成パズルを `PuzzlePiecesView(revealAll: true)` で 6×4 サムネイル全面表示に。
- 検証: シミュレータで 出会い1→5 を順に進め、フレンド既存=カード非表示/次の出会いのみ、未フレンド(山田たろう)=フレンド申請カード表示→「フレンドに追加」でトースト＋称号「はじめてのフレンド」解放、を確認。ピース選択は Pretender/夜に駆ける/Lemon 等で所持/取得可能/取得不可の3状態を確認。`xcodebuild` は `BUILD SUCCEEDED`。

**Android**
- `PuzzlePieces`（Compose・iOS `PuzzlePiecesView` の移植）を新規追加。6×4・所持ピースのみ Coil でサムネイル表示・未所持は lockedピース・`revealAll`/`mosaic` 対応。
- `PuzzleScreen` を新規追加し、`MainActivity` の PUZZLE タブ（旧プレースホルダ）を差し替え。解放済み・サムネイルあり・所持ピースありのトラックを表示。
- ⚠️ 当環境に `gradlew`/Android SDK が無く**ビルド未検証**。コードは実モデル/VM API（`Track.youtubeThumbnailUrl`・`homeState.heroTrack`・`ProgressBar` 等）に対して記述済み。実機/エミュレータでのビルド確認が必要。

次の候補:
- Android: メロディ（出会いカルーセル＋ピース選択）/コレクション/マイページ各画面の本格実装（要 Android ビルド環境）
- iOS: 取得後導線のスキップ後にも「次の出会いへ」を残すか等の細部調整

### iOS 状態永続化（UserDefaults＋Codable）

これまで iOS は毎起動で進行が全リセットされていた（永続化なし）のを修正。ピース・コイン・経験値・フレンド・課金・推し曲・各設定・クールタイムが起動後も保持される。

- **`Models.swift`**: `Friend` を `Codable` 化。保存用 `TrackProgress`（可変進行のみ）／`SaveState`（全保存項目）を追加。
- **`AppViewModel.swift`**:
  - `objectWillChange` を 1秒デバウンスで購読し、変化があれば自動保存（`MainActor.assumeIsolated` で main 隔離を担保）。
  - `persistIfLoaded()`: 現在の進行を `SaveState` にまとめ JSON で `UserDefaults`（キー `streetmelody.save.v1`）へ保存。
  - `restoreState()`: seed/API ロード後に保存済み進行を上書き反映（トラックは静的フィールドを seed に残し、可変フィールドのみ復元）。`loadAll()` 末尾で呼び、以後 `isLoaded` で保存を有効化。
- 検証: 推し曲に Pretender を追加 → アプリ終了 → 再起動で「推し曲 1/3・Pretender」が復元されることをシミュレータで確認。`xcodebuild` は `BUILD SUCCEEDED`。
  （外部 `defaults write` での復元テストは cfprefsd キャッシュの都合で反映されないが、アプリ内での保存→再起動→復元は正常に動作。）

次の候補:
- iOS 試聴「少し聴く」（YouTube音声30秒・1日3回制限）の実装
- Android 各画面の本格実装（要 Android ビルド環境）
- セーブのスキーマ変更時のマイグレーション（現状はキー `v1` 固定。項目追加時はデコード失敗で進行リセットの可能性があるため、デフォルト補完デコードの導入）

### iOS 試聴「少し聴く」（YouTube音声30秒・1日3回制限）

Web版（YouTube IFrame Player API）と同等の試聴をネイティブ移植。設計書 §5.2/5.3・メロディタブ仕様準拠。

- **`Track`**: `chorusStart`（サビ位置・秒）を追加。seed の実在8曲に Web と同じ値を設定（Pretender 57 / Lemon 68 / 夜に駆ける 52 / 唱 44 / 怪獣の花唄 38 / Anytime 58 / ブルーベリー 55 / ハルジオン 62）。
- **`Models.swift`**: `PreviewRecord{date,count}` を追加。`SaveState` に `previewPlays` を追加し、項目追加で旧セーブが壊れないトレラントデコード（欠損キーはデフォルト補完）に変更。
- **`AppViewModel`**: `previewPlays`/`previewTrackId`、`previewPlaysLeft`/`canPreview`/`startPreview`/`endPreview`/`grantPreviewHintIfNeeded`、`previewDailyLimit=3`、`todayKey()`。試聴回数は永続化（日付が変われば3回に復帰）。
- **`PreviewPlayerView.swift`（新規）**:
  - `YouTubeAudioPlayer`（`WKWebView` + IFrame API）。`allowsInlineMediaPlayback`＋`mediaTypesRequiringUserActionForPlayback=[]` で自動再生、`baseURL=https://www.youtube.com`、サビ位置から `start`。映像は不透明レイヤーで隠し音声のみ。
  - ダークなオーディオプレイヤーUI（波形アニメ・伏せ字タイトル・30秒カウントダウン・プログレスバー・「本日あと N 回試聴できます」・停止/閉じる）。完了時、未解放曲はヒントLv1を自動付与し「🎁 1つ目のヒントを解放しました」を表示。
- **導線**: `MysteryView` 先頭と `MelodyView` カルーセルに「▶ 少し聴く（あとN回）」ボタン（実在動画のみ有効・上限0で無効化）。`ContentView` で `previewTrackId` を全面オーバーレイ表示。
- 検証: 米津玄師(Lemon, 未解放)で試聴 → 30秒カウントダウン→「完了」、回数 3→2、完了時「1つ目のヒントを解放しました」、閉じると「あと2回」表示をシミュレータで確認。`xcodebuild` は `BUILD SUCCEEDED`。

次の候補:
- Android 各画面の本格実装（要 Android ビルド環境）
- iOS: 試聴のサビ位置を実音再生開始（onReady）に同期させ、カウントダウンと音のズレを縮小

### iOS ヒント／答え解放の CM ゲート整合・オフライン化

ユーザーの設計意図（ヒント1・2・答えの解放は**すべてCM視聴を条件**とする）に合わせ、試聴完了時のヒントLv1自動付与を撤回。あわせて解放処理をオフライン（バックエンド非依存）に修正し、シミュレータで「通信エラー」になっていた不具合を解消。

- **試聴のヒント自動付与を撤回**: `PreviewPlayerView` の完了時ヒント付与（`grantPreviewHintIfNeeded`呼び出し・「🎁 1つ目のヒントを解放しました」）を削除し、「試聴おわり。ヒントや確認で曲名を当てよう」に変更。設計書 248 行の「未解放曲はヒント自動付与」より、593/875-877 行の「ヒントはCM/広告で解放」を優先（ユーザー判断）。
- **`applyHint` をオフライン化**: `repository.applyHint`（未提供）依存で「通信エラー」になっていたのを、ローカル `tracks` を直接更新する実装に書き換え。プレミアムは無広告・ヒントチケットがあれば消費（残数表示）してトースト。hint1→`hintLevel≥1`／hint2→`hintLevel≥2`（4択表示）／answer→`answerReady=true`。
- **答え→解放導線**: `MysteryView` の YouTube パネルで `answerReady` 時の「確認して解放」を、外部YouTubeを開かず `unlockTrack` のみ呼ぶ単一アクションに変更（Web の「確認する」に合わせアプリ内完結）。未使用化した `openYouTube` を削除。
- **`AdConfirmModal`**: 「（広告SDKは後日実装。現在は視聴を省略して解放します）」の注記を追加（モックである旨を明示）。実 SDK（Google AdMob/AdSense）連携は後日。
- 検証: Lemon(未解放)で「1つ目のヒントを見る」→視聴する→「1つ目のヒントを解放しました」、「答えを見る」→視聴する→「確認して解放」表示→タップで Lemon/米津玄師 が解放されコレクション(1/24)へ遷移することをシミュレータで確認。`xcodebuild` は `BUILD SUCCEEDED`。

次の候補:
- iOS: 広告 SDK（AdMob）連携の本格実装（CM視聴の実フロー化）
- Android 各画面の本格実装（要 Android ビルド環境）

### iOS サムネイル欠落の修正（ローカルパズル画像のバンドル）

**現状整理（DB/データ層）**: バックエンドAPI（`http://localhost:3001/api`）は未稼働で、実体は `AppViewModel.seedFallback()` のハードコードされたオフライン seed（10曲）＋ UserDefaults 永続化。iOS はサムネイルを YouTube 画像CDN（`i.ytimg.com/vi/<id>/mqdefault.jpg`）から動的取得しており、**ローカル画像を一切同梱していなかった**。そのため架空曲（`youtubeVideoId == nil`：Sunset Drive / Magic Hour）はサムネイルが表示されなかった（Web版は全10曲に `assets/puzzles/<id>/preview.png` を同梱して表示）。

- **画像の同梱**: Web版の `apps/web/assets/puzzles/<id>/preview.png` 10枚を `apps/ios/StreetMelody/Resources/Puzzles/<track_id>.png` にコピー（`pretender`→`track_pretender` に正規化）。XcodeGen の `sources: StreetMelody` 再帰取り込みでバンドル直下へ自動同梱。
- **`Track`（Models.swift）**: 表示用と判定用を分離。
  - `hasYouTubeVideo: Bool` … 実在動画を持つか（30秒試聴／YouTube確認のゲート判定用。架空曲は false）。
  - `bundledThumbnailURL` … `Bundle.main.url(forResource: id, withExtension: "png")` で同梱画像を解決。
  - `thumbnailURL: URL?` … 同梱画像を最優先し、無ければ YouTube CDN。旧 `youtubeThumbnailURL` を置換。
- **`CachedThumbnail`**: `url.isFileURL` のとき `Data(contentsOf:)` でディスクから直接読む分岐を追加（同梱画像は即時・ネットワーク不要）。
- **呼び出し側の整理**: 表示系（`PuzzlePiecesView`/`ArtBlockView`/`PieceSelectView` 等 7箇所）は `thumbnailURL` に、試聴/再生ゲート（`canPreview`/`startPreview`/`MysteryView`/`MelodyView` の各 hasVideo 判定）は `hasYouTubeVideo` に変更。これにより「架空曲も画像は出るが試聴はできない」が正しく両立。
- 検証: `xcodebuild` は `BUILD SUCCEEDED`、`.app` に 10枚の `track_*.png` が同梱されることを確認。シミュレータでコレクション一覧の全曲にサムネイルが表示され、架空曲 Sunset Drive / Magic Hour も Web 同様のプレースホルダ画像（緑グリッド）が表示されることを確認。

次の候補:
- iOS: パズルの各ピース画像（Web版 `piece_01〜24.png`）の同梱検討（現状は preview.png を6×4にスライス表示。Web の手描きピース形状とは異なる）
- iOS: 広告 SDK（AdMob）連携の本格実装
- Android 各画面の本格実装（要 Android ビルド環境）

### バックエンド（Supabase）の起動・カタログ投入・画像CDN準備

将来の「DB/CDN配信＋所有分は端末キャッシュ」に向けた第一歩。既存の Supabase プロジェクトと Go API 雛形を実稼働させた。

**現状把握**: バックエンドは想像以上に出来ていた。Go API（`main.go`＋`api/`、ビルド成功）が iOS/web の期待するエンドポイントを実装済みで、Supabase からカタログ取得→失敗時 seed フォールバックする設計。Supabase プロジェクト `StreetMelody`(`wngtvdgzzlkajtbwsurc`/東京) も実在したが **休止中(INACTIVE)** かつ全テーブル0行だった。スキーマは適用済みで、`tracks` に `thumbnail_url`・`grid_rows/cols`・`chorus_start`、per-user テーブルは `auth.users` 連携の UUID＋TEXT track_id という良設計。RLS もカタログは公開SELECT・per-userは本人のみで適切。

**実施（Supabase MCP 経由）**:
- プロジェクトを **restore（再開）** → `ACTIVE_HEALTHY`。
- **カタログ投入**: artists 8件・tracks 10件（iOS/web の正データ準拠。id は TEXT スラグ、`piece_count=24`、`chorus_start`、`thumbnail_url` は Storage 公開URL）。冪等 upsert。
- **Storage 公開バケット `puzzles` 作成**（5MB上限・png/jpeg/webp）。`thumbnail_url` は `…/storage/v1/object/public/puzzles/<track_id>/preview.png` を指す。
- 検証: anon 公開REST `/rest/v1/tracks` で全曲取得OK。Go API 起動で `catalog loaded from Supabase` を確認し `/api/tracks` が `pieceCount:24`（＝Supabase値）を返すことを確認。

**残（コード結線・別タスク）**:
- Go `api/store/supabase.go` の `supabaseTrack` に `thumbnail_url` を追加 → `model.Track`／APIレスポンス（view）→ iOS `Track` まで結線し、アプリが CDN 画像を使うようにする（現状アプリは同梱画像。`thumbnailURL` のフォールバック構造はそのまま活かせる）。
- 所有パズルの端末ディスクキャッシュ（`ThumbnailCache` を NSCache→永続化）。
- 本番 API のデプロイ先決定（現状 localhost のみ）。バックエンド3系統（Go `api/`・Go `backend/api/`・Node `server/`）の整理。

**ユーザー作業（私が代行不可）**: パズル画像10枚のアップロードは `scripts/upload-puzzles.sh` を service_role キー（環境変数 `SUPABASE_SERVICE_ROLE_KEY`）で実行。※ Storage への匿名 INSERT ポリシー付与は安全側で自動拒否されたため、秘密鍵を手元に留める方式にした。

### サムネイルを YouTube 公式MV から DB 自動投入（アップロード廃止）

上記の「画像アップロード」を見直し。設計書 `StreetMelody_パズル生成仕組み設計書.md` §2 の条件「パズルは **YouTube公式MVまたは公式リリックビデオのサムネイル** をもとに作成する」に基づき、実在曲はアップロード不要で YouTube から取得する方式に統一した。

- **DBトリガー `set_thumbnail_from_youtube()` を追加**（migration `derive_thumbnail_from_youtube`）。`tracks` の INSERT/UPDATE 時、`thumbnail_url` が NULL かつ `youtube_video_id` があれば `https://i.ytimg.com/vi/<id>/maxresdefault.jpg`（1280×720）を自動生成。明示指定された URL は上書きしない。→ **新規曲は `youtube_video_id` を入れるだけでサムネが付く仕組み**（ダミー挿入で自動生成を確認、行は削除）。
- **バックフィル**: 公式MVあり8曲は YouTube maxres に統一（先に入れた Storage URL を置換）。公式MVなしの架空2曲（sunset_drive / magic_hour）は `thumbnail_url = NULL`（アプリ側でグラデーション/同梱プレースホルダにフォールバック）。
- 検証: anon REST で全曲の `thumbnail_url` を確認。Lemon の maxres は実画像 HTTP 200・78KB を配信。全8曲 maxresdefault 利用可（200）。
- **アップロードは不要化** → `scripts/upload-puzzles.sh` を削除。Storage バケット `puzzles` は将来の架空曲アート/ピース画像用に残置（現状未使用）。

**残（コード結線）**: アプリ/Go API はまだ DB の `thumbnail_url` を使っていない。Go `supabaseTrack`→`model.Track`→APIレスポンス→iOS `Track` まで結線すれば、アプリが公式MVサムネ（CDN）を表示するようになる（同梱画像からの移行）。所有パズルの端末ディスクキャッシュ（オフライン対応）も別途。

### thumbnail_url のアプリ結線＋架空2曲の削除

**(1) thumbnail_url を Supabase→Go API→iOS まで結線**
- Go `api/store/supabase.go`: `supabaseTrack` に `thumbnail_url` を追加し `model.Track.ThumbnailURL` へマップ。
- Go `api/model/model.go`: `Track`／`TrackView` に `ThumbnailURL string json:"thumbnailUrl,omitempty"` を追加（未解放でも返す）。`store.go` の `TrackView()` で値をコピー。
- iOS `Models.swift`: `Track` に `thumbnailUrl: String?`（API/DB由来）を追加。`thumbnailURL`（表示用 computed）の優先順位を **① DB(thumbnailUrl) → ② 同梱画像 → ③ YouTube直** に変更。フォールバック構造は維持。
- 検証: Go API 起動 → `/api/tracks` が **8曲**を返し、各曲に `thumbnailUrl=https://i.ytimg.com/vi/<id>/maxresdefault.jpg` が乗ることを確認（Supabase→Go→JSON 全段疎通）。`go build ./...` OK、iOS `BUILD SUCCEEDED`。

**(2) 架空2曲（Sunset Drive / Magic Hour）をテストデータから削除**
- Supabase `tracks` から2曲を DELETE（残8曲）。
- 削除＋参照修正したファイル: iOS `AppViewModel.swift`（seed 2曲・デイリープレイリスト・`totalPuzzles 10→8`）、Go `api/store/store.go`＋`backend/api/store/store.go`（seed・`dailyTrackIDs`）、`apps/web/src/data.js`（ASSETS・track定義・playlist trackIds・recentlyAdded）、`server/db/seed.js`。デイリー/最近追加の参照は実在曲（track_show / track_kaiju 等）へ差し替え。
- iOS 同梱の `track_sunset_drive.png`／`track_magic_hour.png` を削除（→ 8枚）。`xcodegen generate` 再生成。
- 検証: コード全体に架空曲の参照が残らないことを grep で確認。各seedビルド/構文OK。シミュレータでコレクション「曲パズル **0/8**」・ホームのヒーローが実在曲（唱）の実アートワークになることを確認。

### iOS をライブAPIに接続（カタログ/サムネイルのみ・overlay方式）

iOS アプリの `loadAll()` を、seed を土台にしつつカタログ（曲・サムネイルURL）だけライブAPI（`localhost:3001` → Supabase）から取得する形に接続した。

- **`loadTracks()` を overlay 方式に変更**: 旧実装は API 結果で `tracks` を丸ごと置換しており、API 稼働時に `youtubeVideoId`/`chorusStart`/所持ピース等の seed 情報が失われた。新実装は **API の `thumbnailUrl` だけを既存 seed トラックに重ねる**（進行状態・動画ID等は seed/保存を優先）。これで画像の出所が DB/CDN（公式MVの maxres）に切り替わり、API 不通時は seed/同梱画像へフォールバック。`restoreState()` は該当フィールドのみ書き換えるため `thumbnailUrl` は保持される。
- **他のローダーは当面 seed 維持**: `loadUser`/`loadCollection`/`loadMission`/`loadEncounter`/`loadPlaylist` はバックエンドの per-user データ＋認証が未整備（ゲスト"Mia"・0コイン等のプレースホルダ）でプロトタイプ体験が劣化するため、`loadAll()` の taskgroup から外した（関数は残置、整備後に有効化）。
- 検証: ローカルで Go API を起動しアプリ起動 → 全ローダー版では home のユーザー名が API ゲスト「Mia」に変化＝ライブAPI到達を確認。overlay 限定版に戻すと「StreetMelody ユーザー」/ヒーロー唱（22/24・実アート）を維持しつつ、サムネイルは DB/CDN 取得。iOS `BUILD SUCCEEDED`。
- 補足: 本番では API 未デプロイ（`api.streetmelody.app` 未設置）のため通常は seed+同梱画像で動作。API をデプロイ/起動した時のみ DB/CDN サムネが有効化される。

リポジトリ整備: 生成物 `apps/ios/StreetMelody.xcodeproj/`（XcodeGen が `project.yml` から再生成）等を除外する `.gitignore` を追加。

### main へマージ＋Cloud Runデプロイ準備＋認証プラン

- **マージ**: `feat/supabase-catalog-thumbnail` を `main` へ fast-forward マージ（ローカル完了）。**push はこの作業環境に GitHub 認証情報が無く失敗**（`could not read Username`）。ユーザーの認証済み端末から `git push origin main` が必要。remote=`github.com/haku389/StreetMelody.git`。
- **Cloud Run デプロイ成果物**（gcloud/docker 未インストールのため実デプロイは未実行・ユーザー実行用に準備）:
  - `Dockerfile`（multi-stage、ルート `main.go`＋`api/` のみ、外部依存なし→ distroless static、PORT=8080）。`go build` 同等コマンドでローカル検証 OK。
  - `.dockerignore`、`scripts/deploy-cloudrun.sh`（`gcloud run deploy --source .`＝Cloud Build利用でローカル docker 不要、REGION 既定 asia-northeast1、anon キー注入）。
  - 手順書 `docs/deploy-cloudrun.md`。デプロイ後 iOS の本番 baseURL を Cloud Run URL に差し替え or `api.streetmelody.app` をドメインマッピング。
- **認証＋per-user 接続プラン** `docs/auth-peruser-plan.md`: RLS のため per-user 書き込みには JWT か service_role が必須で、**方式A（クライアント直結・Supabase直叩き＝web と統一・推奨）** と **方式B（Go API 集約＋service_role）** に分岐。方式確定後にフェーズ実装（iOS 匿名Auth→per-user 読み書き→ローダー再接続）。

### 方式A 採用：iOS Supabase 認証基盤（Phase 1）

ユーザーが **方式A（クライアント直結）** を選択。iOS が匿名サインインで JWT を取得し、per-user データを Supabase に直接読み書きする構成へ。

- **`Services/SupabaseClient.swift`（新規）**: GoTrue REST ベースの最小クライアント。匿名サインイン（`POST /auth/v1/signup`）＋セッション永続化（refresh_token を UserDefaults 保存）＋トークン更新（`grant_type=refresh_token`）＋ per-user 用 PostgREST ヘルパー `rest(method:query:body:)`（anon キー＋ユーザー JWT を付与）。`actor` で実装。
- **起動時ブートストラップ**: `loadAll()` の taskgroup に `SupabaseClient.shared.bootstrap()` を追加（保存セッション復帰 or 匿名サインイン）。**非破壊**：匿名無効・通信不可なら静かに失敗し seed 運用継続。iOS `BUILD SUCCEEDED`。
- ⚠️ **前提トグル（ユーザー作業）**: プロジェクトは現在 `anonymous_provider_disabled`。Supabase ダッシュボード → Authentication → Sign In/Providers → **Anonymous sign-ins を ON** にする必要あり（Auth 設定は MCP/SQL から変更不可）。ON 後に匿名サインインの端到端検証が可能。
- **次（Phase 2・トグルON後）**: per-user テーブル（`profiles`/`collected_pieces`/`unlocked_tracks`/`hint_levels`/`friendships`）の読み書きを `SupabaseClient.rest` 経由に。`AppViewModel` の `collectPiece`/`unlockTrack`/`applyHint` 等を Supabase 同期に。`loadAll()` のコメントアウト中ローダーを Supabase 直クエリで再接続。

push: ここまで `main` を `origin/main` に push 済み（`gh` 認証を利用）。

### アプリ名リネーム：MelodyLien → StreetMelody

アプリ名を全面改名。コード/ファイル名/ドキュメントを一括置換（`MelodyLien`→`StreetMelody`、`melodylien`→`streetmelody`、README 読み「メロディリアン」→「ストリートメロディ」）。

- **内容置換**: 約58テキストファイル（iOS/Android/Go/web/docs/scripts/設定）。bundle id `com.melodylien.app`→`com.streetmelody.app`、Go module `melodylien`→`streetmelody`（root＋backend）、永続化キー `melodylien.save.v1`/`…supabase.session.v1`→`streetmelody.*`。
- **ディレクトリ/ファイル改名**: `apps/ios/MelodyLien`→`apps/ios/StreetMelody`、`MelodyLienApp.swift`→`StreetMelodyApp.swift`、Android `com/melodylien`→`com/streetmelody`＋`MelodyLienApp.kt`→`StreetMelodyApp.kt`。生成物 `MelodyLien.xcodeproj` 削除→`xcodegen` で `StreetMelody.xcodeproj` 再生成。
- 検証: `go build ./...`（root/backend）OK、web JS `--check` OK、iOS `BUILD SUCCEEDED`（`StreetMelody.app`/`com.streetmelody.app`）。シミュレータでヘッダー「StreetMelody ユーザー」を確認。追跡対象に残存参照なし（`git grep`）。
- 補足（別管理・未変更）: ①リポジトリ root ディレクトリ名・GitHub リポジトリ名（`haku389/MelodyLien`）はセッション安定のため未変更。②Supabase プロジェクト表示名「MelodyLien」（ref `wngtvdgzzlkajtbwsurc` 不変・機能影響なし）。③Obsidian 保管庫の設計書（リポジトリ外）。いずれも必要なら別途リネーム可。

### Cloud Run 本番デプロイ完了＋iOS本番URL接続

- **デプロイ成功**: `scripts/deploy-cloudrun.sh`（Compute デフォルトSAに `cloudbuild.builds.builder` 自動付与＋`--quiet`）で Cloud Run（asia-northeast1）にデプロイ。Service URL `https://streetmelody-api-226967968391.asia-northeast1.run.app`。検証: `/api/tracks` が **HTTP 200・8曲＋maxres thumbnailUrl**（Supabase からカタログ取得）を返すことを確認。
- **iOS 本番URL接続**: `APIService.swift` の `#else`（RELEASE）baseURL を `https://api.streetmelody.app/api` → 上記 Cloud Run URL に変更。iOS `BUILD SUCCEEDED`。DEBUG は引き続き `localhost:3001`。将来カスタムドメイン `api.streetmelody.app` をマッピングしたら差し替え可。
- **匿名サインイン有効化を確認**＋**RLS per-user 経路を検証**: 匿名JWTで `collected_pieces` を 自分=201/SELECT本人のみ/なりすまし=403/DELETE=204。方式A のデータ経路が安全に通ることを実証（Phase 2 の前提クリア）。

### Task 3 Phase 2：per-user 進行を Supabase 直結（方式A）

iOS の所持ピース・解放状態を Supabase に直接読み書き（RLS で本人分のみ）。

- **`SupabaseClient`**: per-user 進行 API を追加。`fetchProgress()`（`collected_pieces`/`unlocked_tracks` を GET→`UserProgress`）、`upsertPiece(trackId:piece:)`／`upsertUnlock(trackId:)`（冪等 upsert・`on_conflict`＋`resolution=ignore-duplicates`）。すべて認証トークン付き。
- **`AppViewModel`**: `collectPiece` でピース追加時に `Task { upsertPiece }`、`unlockTrack` で `await upsertUnlock`。`loadAll()` の `restoreState()` 後に `mergeRemoteProgress()` を呼び、Supabase の自分の進行を seed/ローカルへ和集合マージ（remote=真の解放を反映）。未サインイン時は no-op で seed 運用継続。
- **E2E 検証（シミュレータ＋実DB）**:
  - 起動で匿名サインイン → `auth.users(is_anonymous)` が 4→5 に増加（アプリが認証）。
  - UI で Pretender のピース13を取得 → `collected_pieces` に `(該当anon user, track_pretender, 13)` が即時記録（アプリ→Supabase 書込みを実証）。
  - 再起動で `mergeRemoteProgress` がクリーンに実行（クラッシュなし）。読込（RLSスコープGET）は前段 curl で実証済みの同一機構。
  - iOS `BUILD SUCCEEDED`。
- **現状の同期範囲**: 所持ピース・解放のみ（DB に存在するテーブル）。ヒントレベル/答え確認・コイン/フレンド等は今後（テーブル追加 or profiles 拡張）。匿名ユーザーはインストール毎に新規発行のため、再インストール跨ぎの復元には将来「匿名→メール/SNS の昇格（アカウント連携）」が必要（web 実装済みの方式を移植予定）。

### 同期範囲の拡張（ヒント/コイン/フレンド）＋アカウント連携＋独自ドメイン手順

**① 同期範囲拡張**:
- DB migration `add_hint_levels_and_friend_location`: `hint_levels`(user_id,track_id,level,answer_ready) 新規＋RLS（本人のみ select/insert/update）、`friendships` に `location_label` 列追加。`profiles` は signup トリガーで自動生成済み・UPDATEポリシーありのためコインはそのまま使える。
- `SupabaseClient`: `fetchUserState()`（pieces/unlocked/hints/coins/friends をまとめて取得）、`upsertHint`/`updateCoins`(profiles PATCH)/`upsertFriend`。
- `AppViewModel`: `applyHint`→`upsertHint`、コインは `persistIfLoaded` で変化時のみ `updateCoins`（重複防止に `lastSyncedCoins`）、フレンド追加・交換回数増で `upsertFriend`。`mergeRemoteProgress` を全状態マージへ拡張（ピース和集合／解放・ヒントON反映／コインは remote 実値>0 採用・新規は seed を push／フレンド未所持名を追加）。
- 検証（匿名トークン＋実DB）: `hint_levels` insert=201・再upsert=200(merge)・読戻し正・delete=204、`profiles` coins PATCH=204→555反映。フレンドは同一 upsert パターン。

**② アカウント連携（匿名→メール、再インストール跨ぎ復元）**:
- `SupabaseClient`: `upgradeToEmail`(PUT /user)・`signInWithEmail`(grant_type=password)・`signOut`、`email`/`isAnonymous` を保持。`AppViewModel`: `linkAccount`/`signInAccount`(復元時 `mergeRemoteProgress`)/`signOutAccount`、`accountEmail`/`isGuestAccount` を Published。
- UI: `AccountLinkView`（連携/ログインのセグメント・メール/パスワード）を新規。`MyPageView` の `accountSection` を動的化（ゲスト→連携ボタンでシート、連携済み→メール表示＋ログアウト）。iOS `BUILD SUCCEEDED`。
- 検証: PUT /user は gmail 宛で正常到達（アプリは `JSONSerialization` で正しいJSONを送る）。ただし **`Confirm email` が有効**のため確認メール送信→未確認では即ログイン不可（`over_email_send_rate_limit` も観測）。⚠️ **ユーザー作業**: Supabase ダッシュボード → Authentication → Email の **「Confirm email」を OFF** にすれば連携→即ログイン（復元）が成立（匿名トグルと同様）。確認メール運用にするなら確認リンクのUXが別途必要。

**③ 独自ドメイン**: 手順書 `docs/custom-domain.md`（Cloud Run domain-mappings＋DNS＋iOS baseURL 戻し）。前提＝ドメイン所有＋DNS編集。任意・後回しでOK（API はユーザー非表示）。

### ログイン手段の拡張：Supabase Swift SDK ＋ Apple / Google / Spotify

方式A の上に複数ログイン手段を実装（認証は SDK、per-user データは実証済み REST 経路を維持）。

- **SDK 導入**: `supabase-swift 2.48.0`（SPM, `project.yml` の `packages`）。当環境で解決・リンク・ビルド成功。
- **`SupabaseAuthKit`**: SDK で各プロバイダ認証 → `SupabaseClient.adoptSession` で REST データ層へ橋渡し。
  - Apple: `signInWithIdToken(.apple)`（ネイティブ Sign in with Apple ＋ nonce）。
  - Google/Spotify: `signInWithOAuth(.google/.spotify, redirectTo: com.streetmelody.app://login-callback)` ＋ `ASWebAuthenticationSession`（表示アンカー `WebAuthPresenter`）。
- **UI**: `AccountLinkView` に `SignInWithAppleButton`／Google／Spotify ボタン。`project.yml` に `CFBundleURLTypes`（`com.streetmelody.app` スキーム）。`AppViewModel` に `signInWithApple/Google/Spotify`（成功時 `mergeRemoteProgress` で復元）。
- **設定手順書**: `docs/apple-signin-setup.md`、`docs/oauth-google-spotify-setup.md`。
- **検証（Google/Spotify, 設定後）**:
  - Supabase authorize エンドポイントが 302 でプロバイダへ：Google→`accounts.google.com/...client_id=226967968391-...`、Spotify→`accounts.spotify.com/...client_id=bbdf...`（プロバイダ有効化＋リダイレクト許可が反映済み）。
  - シミュレータで「Google で続ける」→ ASWebAuthenticationSession 同意ダイアログ（`supabase.co`）→ **実際の Google ログイン画面**（戻り先 `wngtvdgzzlkajtbwsurc.supabase.co`）まで到達を確認＝アプリ側 OAuth 配線を E2E 検証。実ログイン情報入力のみユーザー作業。
- **Apple は保留**: 本人確認書類が用意できず Apple Developer Program 登録不可のため、コード基盤のみ（entitlement／Team は未設定）。
- **残（設定後に確定）**: 「新規サインイン」か「匿名→昇格（`linkIdentity`でデータ引き継ぎ）」かの確定と E2E。

### OAuth を SDK → REST+PKCE に切替（シミュレータ -1005 解消）＋昇格(link)

Supabase Swift SDK のネットワーク呼び出しがシミュレータで常に `-1005`（HTTP/3 QUIC ストール）になり、匿名サインインすら失敗する問題が判明。SDK 内部が独自セッションを使うわけではなく（global session を使用）、設定変更でも回避できなかった。一方、自前の REST 直叩き(URLSession)は同じエンドポイントでシミュレータでも成功する。

- **OAuth を REST+PKCE に再実装**（`SupabaseClient`）: `oauthAuthorizeURL(provider:link:)`（sign-in は `/auth/v1/authorize` を直接、link は `/auth/v1/user/identities/authorize?...&skip_http_redirect=true` を Bearer 付きで取得して URL を得る）、`oauthExchange(callback:)`（`/token?grant_type=pkce` で code↔session 交換）、`signInWithAppleIDToken(_:nonce:link:)`（`/token?grant_type=id_token`）。PKCE verifier/challenge は CryptoKit。
- **`SupabaseAuthKit`** は SDK を使わず ASWebAuthenticationSession の提示のみを担当。**Supabase Swift SDK(SPM) を `project.yml` から削除**（未使用＝重い依存を排除）。
- `AppViewModel`/`AccountLinkView`: Apple/Google/Spotify を `link:` 対応（連携=昇格 / ログイン=切替）。
- 検証: REST の link authorize 取得を curl で確認 → **-1005 ではなく** `404 manual_linking_disabled`（API に到達＝REST 経路はシミュレータで動く）。
- ⚠️ **昇格(link) の前提（ユーザー作業）**: 上記エラーのとおり、Supabase で **「Manual linking」を有効化**する必要がある（既定で無効）。有効化後に link の Web 認証が開く（→ プロバイダログイン→ 昇格）。sign-in（ログイン）側は manual linking 不要で動作。

### 実機での OAuth（Google）連携フロー E2E 検証 ✅（2026-06-25）

これまでシミュレータ止まりだった OAuth 連携を、**実機（マリオマリオ / iPhone 16 Pro Max, iOS 26.5）で初めて E2E 成功**。直前コミット群（HTTP/3 緩和・`-1005` リトライ・stale session 自己修復・OAuth 経路の HTTP ステータス/ボディ可視化・ボタン別ローディング）が実ネットワークで通ることを確認。

- **実機ビルド到達までの環境整備**:
  - ディスク逼迫（Data ボリューム 99–100%）で DerivedData ビルド不能 → 空き確保で復旧。
  - Mac がバッテリー駆動 14%・残 15 分（USB-C 接続の iPhone へ給電して消耗加速）→ **AC 電源接続**で安定化。ネットワーク不安定の一因でもあった。
  - `xcodebuild` が `No Accounts` → 原因は **Xcode に Apple ID 未サインイン**（証明書は過去分が keychain に残存）。Xcode → Settings → Accounts に `y.to_fumm0329@icloud.com` を追加で解消。
  - 署名: Automatic、**Team = とうや やまさき (Personal Team)**、`com.streetmelody.app`、Xcode Managed Profile。**無料プロビジョニングのため有効期限 7 日**（7 日ごと再インストール必要）。
  - 初回 Run でキーチェーン署名鍵アクセス許可（SecurityAgent）→ 「信頼されていないデベロッパ」をデバイスで信頼 → 再 Run で起動。
- **検証結果**: 実機でアプリ起動（デバッガ接続・クラッシュなし）→ 「Google で続ける」→ 実 Google ログイン → アプリ復帰まで成功（ユーザー確認）。コンソールに OAuth 関連エラースタックなし。
- **客観確認の制約**: Supabase 本番 `auth.identities` の参照は PII 保護でツール側がブロック（集計クエリも不可）。identity 紐付けの DB 直接確認は、参照許可付与かアプリ内「連携済み」表示で代替する。

### 次フェーズ計画：3 音楽サービス連携（ログインとは別）＋再生中曲の取得＋共有

**目的**: 認証（ログイン）とは独立に、ユーザーが Spotify / Apple Music / （第 3 サービス）と接続し、「今聞いている曲（now playing）」を取得して他ユーザーと共有できるようにする。G-3 は模擬実装のため、ここで実 API 連携へ拡張する。

- 対象サービス候補: **Spotify**（Web API: `GET /v1/me/player/currently-playing`）、**Apple Music**（MusicKit / `SystemMusicPlayer` で再生中取得）、第 3 = 要確定（YouTube Music は公式 now-playing API なし、LINE MUSIC 等も要調査 → 候補確定が最初のタスク）。
- 認証との分離: ログインは既存の Supabase OAuth を維持。音楽連携は**サービス別アクセストークンを別管理**（Spotify は scope `user-read-currently-playing`/`user-read-playback-state` で別 OAuth、Apple Music は MusicKit のユーザートークン）。
- データ/共有: now-playing を Supabase の公開テーブル（例 `now_playing(user_id, service, track, artist, updated_at)` ＋ RLS）に upsert → フレンドが購読/取得して共有表示。
- 未確定事項（要相談）: ①第 3 サービスの確定、②取得契機（手動更新 / バックグラウンド・ポーリング / すれちがい連動）、③共有範囲（フレンドのみ / 公開）。

### 音楽サービス連携 実装（M-1〜M-5・ビルド緑）

ユーザー判断: **取得は「StreetMelody を前面で開いている時のみ」**（＝サーバーポーリング不要・トークンのサーバー保管なし・全クライアント処理）。共有は**本人が都度選択**。3 サービスは Spotify / Apple Music を実 API、YouTube Music は手動共有。

- **M-1 DB**（`add_now_playing` ＋ `now_playing_add_display_name`）: `now_playing(user_id PK, service, track_title, artist, artwork_url, started_at, updated_at, visibility, display_name)` ＋ RLS（本人=全操作 / `visibility='public'` は認証ユーザーが read）。共有フィードで `profiles` を跨いで読まずに済むよう **display_name を非正規化**（共有者名）。security advisor は既存同様の `auth_allow_anonymous_sign_ins` WARN のみ（匿名認証前提のため許容）。
- **M-2 iOS基盤**: `Models.swift` に `MusicService`/`NowPlaying`。`SupabaseClient` に `upsertNowPlaying`(on_conflict=user_id, merge) / `clearNowPlaying` / `fetchSharedNowPlaying`(visibility=public, updated_at desc, 自分除外) ＋ ISO8601 日付パース。
- **M-3 Spotify**（`Services/MusicNowPlaying.swift`・`MusicConnectManager`）: **ログインとは別の専用 OAuth**（Authorization Code + PKCE を accounts.spotify.com 直結、client_id `bbdf2c9d…`、redirect `com.streetmelody.app://spotify-callback`、scope `user-read-currently-playing user-read-playback-state`）。`ASWebAuthenticationSession`（`WebAuthPresenter` 再利用）→ code 交換 → **トークンは Keychain 保管**・期限切れは refresh_token で自動更新。`me/player/currently-playing`（204=非再生は nil）。HTTP/3 は `assumesHTTP3Capable=false` で緩和。
- **M-4 Apple Music**: `MPMusicPlayerController.systemMusicPlayer.nowPlayingItem` を読む（`NSAppleMusicUsageDescription` ＋ `MPMediaLibrary` 許可・**有料プログラム不要**／フル MusicKit は不使用）。画像URLは取れないため artwork は nil。
- **M-5 ViewModel/UI**: `AppViewModel` に `connectMusicService`/`disconnectMusicService`/`refreshNowPlaying`（再生中を Spotify→Apple Music の順で採用）/`setNowPlayingShared`/`shareManualNowPlaying`/`loadSharedFeed`、`myNowPlaying`/`sharedFeed`/`nowPlayingBusy` を Published。`MyPageView` に連携トグル実機能化・「今聴いている曲」カード（更新／**この曲を共有する⇄共有をやめる**）・手動共有シート・「みんなの今聴いてる曲」公開フィードを追加。
- **共有範囲（初版）**: `friendships` の `friend_user_id` が nullable で双方向 UUID 連結が未確立のため、初版は **private/public（都度選択）**。「フレンドのみ」は friendships の双方向化後に対応予定。
- 検証: シミュレータ `BUILD SUCCEEDED`（xcodegen 再生成込み）。
- ⚠️ **ユーザー作業**: Spotify Developer Dashboard の **Redirect URIs に `com.streetmelody.app://spotify-callback` を追加**（未追加だと連携が失敗）。
- 残（M-6）: **実機で Spotify/Apple Music の now-playing 取得・共有・フィード表示を検証**（前面取得のため実機で実再生して確認）。

### Spotify を Web API → App Remote SDK へ切替（無料アカウント対応）＋ now-playing ライブ化（M-6/M-7・実機検証済み ✅）

**Spotify Web API は使えないと判明**: 実機で `currently-playing` が連鎖的に失敗。切り分けの結果、最終的に **HTTP 403「Active premium subscription required for the owner of the app」** ＝ **Web API の `me/player/*` は開発者アプリのオーナーが Spotify Premium でないと使えない**（無料アカウント不可）。途中の「user may not be registered」は開発モードの User Management 由来だが、本質は owner Premium 要件。→ **Spotify iOS SDK（App Remote）に切替**（端末の Spotify アプリへ直接つなぐため無料アカウントでも再生状態を読める）。

- **SDK 導入**: `spotify/ios-sdk` を **SPM** で追加（`packages` に `https://github.com/spotify/ios-sdk` from 5.0.1、product `SpotifyiOS`）。device/simulator 両対応の binary xcframework。`Info.plist` に `LSApplicationQueriesSchemes: [spotify]`。
- **`SpotifyAppRemoteController`**（`Services/SpotifyAppRemote.swift`）: `authorizeAndPlayURI("")` で Spotify アプリを起動・認可（app-switch）→ 戻りURL（`com.streetmelody.app://spotify-callback`）を App の `onOpenURL` → `authorizationParameters(from:)` でトークン取得（Keychain 保管）→ `connect()` → `appRemoteDidEstablishConnection` で `playerAPI` を **subscribe**。以後 `playerStateDidChange` でライブに曲・再生/一時停止が届く。`resume/pause/skipToNext/skipToPrevious` で操作。
  - **教訓**: `connect()` 単体は session 未確立で `com.spotify.app-remote#-1000`。初回は必ず `authorizeAndPlayURI` を通す。`prefersEphemeral` 等の Web OAuth は不要になり、PKCE Web 認可コードは撤去。
- **ライブ now-playing（M-7）**: `MusicConnectManager` を `ObservableObject` 化し `@Published active: ActivePlayback?`（**再生中のみ**・停止/古い残りは除外）。
  - Apple Music: `MPMusicPlayerController.systemMusicPlayer` を通知監視＋**2秒ポーリング併用**（通知だけだと初回状態を取りこぼすため。これが実機で表示されなかった主因→ポーリングで解決）。`.playing`/能動セッション中の`.paused`のみ採用（起動直後の古い一時停止アイテムを弾く `appleWasPlaying` ガード）。
  - Spotify: App Remote の購読でライブ反映。両方再生中なら Spotify 優先。
  - **ホームにミニプレイヤー**を新設（`HomeView.nowPlayingPanel`、`@ObservedObject music = MusicConnectManager.shared` を直接購読）: サービス名・曲名・アーティスト＋**再生/一時停止・前後ボタン**＋**「共有する」トグル**。マイページは連携トグルと「みんなの今聴いてる曲」フィードのみに整理。
  - 共有はトグル化（`nowPlayingShared` を永続化）: ON の間、曲が変わるたび `now_playing` に自動 upsert、停止/OFF で削除。
- **実機検証済み ✅**: Apple Music・Spotify とも、再生中のみ表示／曲変更で自動反映／再生・一時停止・前後操作／共有 を確認。無料 Spotify アカウントで App Remote 接続成功。
- ⚠️ **ユーザー作業（再掲）**: Spotify Dashboard の Redirect URIs に `com.streetmelody.app://spotify-callback` 追加済み。署名は個人 Team（無料プロビジョニング＝7日有効）。

### フレンド共有（フレンドコードで相互登録 → friends 可視性）（M-8）

すれちがいで増える friends は seed の擬似 id で実ユーザー UUID が無い（実フレンドグラフが不在）。そこで **フレンドコード方式**で実 UUID リンクを作り、now-playing の **friends 可視性**を実装。

- **DB**（`now_playing_friends_visibility`）: `now_playing.visibility` の CHECK に `'friends'` を追加。RLS `now_playing_select_friends` を追加＝`visibility='friends'` の行は、**閲覧者が friend_user_id として登録した相手**の行のみ読める（`exists(select 1 from friendships f where f.user_id=auth.uid() and f.friend_user_id=now_playing.user_id)`）。friendships は本人行のみ select 可なのでサブクエリは安全。
- **`SupabaseClient`**: `addFriendByCode(friendUserId:nickname:)`（friendships に user_id=自分・friend_user_id=相手 を upsert。36文字/自分除外を検証）、`myFriendCode()`（=自分の user_id）。`fetchSharedNowPlaying` は `visibility=eq.public` 固定をやめ、**RLS に委ねて public＋自分が登録したフレンドの friends 行**を返す（自分は除外）。
- **`AppViewModel`**: 共有を `nowPlayingShared:Bool` → **`nowPlayingShareMode:String`（"off"|"friends"|"public"・永続化）**へ。`setNowPlayingShareMode` で即時反映、`syncSharedNowPlaying` は mode を visibility に使用。`friendCode` を `refreshAccountState` で取得。`addFriendByCode(code:nickname:)`。
- **UI**: ホームのミニプレイヤーの共有ボタンを **3択メニュー（オフ/フレンド/公開）** に。マイページに **フレンドコード**セクション（表示・コピー・「コードでフレンド追加」シート）。共有フィード行に `friends` の **「フレンド」バッジ**。
- 検証: シミュレータ／実機 `BUILD SUCCEEDED`・インストール済み。**E2E（相手の friends 曲が見える）の確認には2アカウント必要**（コード交換 → 双方が相手を登録）。単体ではコード表示・追加・共有モード切替まで確認可。
- 補足: 友だち関係は一方向（登録した相手を見られる）。相互に見るには双方が相手コードを登録。フレンドコード＝user_id（36文字）。

### フォロー型ソーシャル化（相互フォロー＝フレンド／ベストフレンド／公開範囲4段階）（M-9）

SNS のフォロー型へ刷新。**相互フォロー＝フレンド**、フレンドの中から**ベストフレンド（親しい友達）**を選択、共有範囲は **オフ / ベストフレンド / フレンド / 全体公開** の4段階。

- **DB**（`follows_and_bestfriends`）: `follows(follower_id, followee_id, nickname, is_best, created_at)` PK(follower,followee)・自己参照禁止 check。RLS: 自分の行は insert/update/delete 可、`follows_select_involved` で**自分が関与する行（follow した/された）**を select 可（相互判定・被ベスト判定に必要）。`now_playing.visibility` に `'bestfriends'` 追加。friends ポリシーを **follows ベースの相互フォロー**へ置換、`now_playing_select_bestfriends`（所有者が閲覧者を is_best 指定）を追加。
- **`SupabaseClient`**: `SocialUser{userId,nickname,following,followedBy,isBest,isFriend}`、`fetchSocialGraph()`（自分関与の follows を相手ごとに集約）、`followUser(code:nickname:)`／`unfollowUser`／`setBestFriend(_:isBest:)`。`fetchSharedNowPlaying` は RLS に委ね public＋相互フレンドの friends＋被ベストの bestfriends を返す。
- **`AppViewModel`**: `social:[SocialUser]`、`loadSocialGraph`／`followByCode`／`unfollow`／`toggleBestFriend`、`nowPlayingShareMode` を4値対応。起動・マイページ表示で社交グラフ読込。
- **UI**: ホームの共有メニューを **4択（オフ/ベスト/フレンド/公開）**。マイページに **フォロー/フレンド**セクション（自分のコード＋「フォロー追加」、フォロー一覧に フレンド/フォロー中/フォロワー/★ベスト バッジ、フレンドのみ★トグル、解除/フォロー返し）。
- **フォロー導線**: ユーザー検索基盤が無いため**コード（user_id）でフォロー**。相互フォローでフレンド成立 → フレンドのみベスト指定可。
- 検証: シミュレータ／実機 `BUILD SUCCEEDED`・インストール済み。**E2E は2アカウント必要**（相互フォロー→ベスト指定→各可視性で相手フィードに出るか）。

### 次フェーズ設計：メロディコード・ソーシャル（プロフィール基盤＋メロディミックスでベスト成立）

方針転換：ベストフレンドは**コード手入力ではなく「すれちがいで出会った実ユーザー」へのフォロー＋儀式**で成立させる。各ユーザーに**約4秒のメロディ**を付与（初期は自動、将来は自作）し、**メロディミックス**（2人のメロディを混ぜて再生）でベスト成立、遠隔は**メロディコード**交換。実ユーザー基盤（ログイン後の handle/誕生日/性別/bio/お気に入り曲のプロフィール設定）が前提。**まず設計を固める**段階。

- 設計詳細は **[melody-social-design.md](melody-social-design.md)** に集約（関係モデル／プロフィール／メロディ表現／**メロディミックスの音楽設計＝ペンタトニック固定で常に協和**／ベスト成立フロー／データモデル／段階計画）。
- ⚠️ 重要技術前提：**iOS 公開APIでは iPhone 同士の NFC P2P 通信は不可**。近接ハンドシェイクは **BLEすれちがい（既存）＋QR/MultipeerConnectivity** を推奨（NFCはタグ設置型イベントの将来オプション）。→ 要意思決定。

### P1 実装：プロフィール基盤＋メロディ（生成・音色・試聴）

設計確定（近接トリガー＝**QRで確定**／NFC・HCEは不可：Core NFC 読取自体が有料Program必須・HCEは特別審査制）。P1 を実装。

- **P1-1 DB**（`profiles_social_fields` / `check_handle_available_rpc`）: `profiles` に handle(unique, lower部分索引)・bio・favorite_artist_ids・favorite_track_ids・birthday・gender・melody(jsonb)・melody_seed・profile_visibility(jsonb) を追加。handle 空き確認 RPC `check_handle_available`（SECURITY DEFINER）。
- **P1-2 メロディ**（`Services/Melody.swift`）: `Melody`（音符列＋meta）／**user_id シードの決定的ペンタトニック生成**（Cメジャーペンタ・110BPM・2小節・主音終止・跳躍制限／**初期値は変更前提**）。**`AVAudioEngine`＋`AVAudioSourceNode` の自前加算合成**で試聴（アセット不要）。**5音色（ピアノ/ベル/マリンバ/オルガン/プラック）**を倍音＋エンベロープで実装し user_id から決定的に割り当て＝「その人の音」。`playMix` は2人の音色が同じなら片方をずらし、相手は+1oct で住み分け。ユーザー確認＝**音の動き/リズム良好・音色分けOK**。
- **P1-3 プロフィールUI**（`Views/Screens/ProfileEditView.swift`）: handle（形式検証＋RPCで空き確認・✓/✗表示）・表示名・自己紹介・誕生日（任意・公開範囲付き）・性別（公開範囲付き）・好きなアーティスト/曲（複数選択）・メロディ試聴。`SupabaseClient` に `fetchMyProfile`/`updateMyProfile`(handle重複=409→文言)/`checkHandleAvailable`。`AppViewModel` に `profile`/`loadProfile`/`saveProfile`/`needsProfileSetup`。**実アカウントで handle 未設定なら起動時にオンボーディングを自動提示**（`ContentView` のsheet）。MyPage ヘッダーに handle 表示＋編集ボタン。
- 必須公開＝表示名・自己紹介・好きなアーティスト・好きな曲。誕生日・性別は項目ごとに公開範囲（公開/フォロワー/フレンド/ベスト/非公開）を設定（他者閲覧フィルタの `get_profile` RPC は P3/P4 で実装予定）。
- 検証: シミュレータ／実機 `BUILD SUCCEEDED`・インストール済み。
- 次：**P2 メロディミックス（対面でのミックス共演）／P3 すれちがい実ユーザー連動／P4 ベスト成立・メロディコード**。

### P1 追補：プロフィールUI改善・コレクション再生・全カタログ検索・外部アプリ再生・MV

- **プロフィールUI 独自化**（`ProfileEditView` を Form → 紫カード基調に作り替え）。誕生日カレンダー日本語化（`ja_JP`）・**誕生日必須**化・テスト用✕クローズ。子画面遷移で入力が消えるバグ修正（`didLoad` ガード）。サインイン/連携直後にオンボーディング自動提示（`presentOnboardingIfNeeded`）。
- **お気に入りを Apple Music 全カタログ検索**：MusicKit カタログ検索は有料Program必須のため、**iTunes Search API**（無料・認証不要）で全曲/全アーティスト検索（アートワーク付き）。`MusicLibrary.swift` の `ITunesSearch`。ローカルライブラリ（MPMediaQuery）限定をやめた（自分のプレイリストしか出ない問題を解消）。
- **コレクションから試聴**：`CollectionView` の一覧行・完成グリッド・アーティストグリッドに ▶ 再生ボタン（タップ=詳細／▶=試聴の住み分けは onTapGesture＋Button）。**試聴の無音バグ修正**＝`PreviewPlayerView` で `AVAudioSession(.playback)` 有効化（マナースイッチでも鳴る）。**解放済みは試聴無制限**（未解放のみ1日3回）。
- **PuzzleView に「この曲を聴く・観る」**：**Apple Music / Spotify をディープリンクで開いて再生**（無料アカウントの現実解＝外部アプリでバックグラウンド再生。Apple Music は iTunes Search で曲URL解決、Spotify は検索URL）。`ExternalMusic`。完成時のみ **「MVを見る」**＝映像つきフル YouTube プレイヤー（`YouTubeMVView`/`YouTubeVideoPlayer`、`vm.mvTrackId`）。全ピース獲得でパズルは自動的にフルサムネイル表示。
- ⚠️ iOS NFC: iPhone間P2Pは不可（HCEは有料＋特別審査・Core NFC読取も有料Program必須）→ 近接トリガーは **QR** で確定（設計書 §6.3）。

### P1 追補2：出会いフロー改善・マスク基準・ミッション、＋P2 メロディミックス

- **試聴の無音を修正**：YouTube埋め込み（実機で不安定）→ **AVPlayer＋iTunes公式30秒プレビュー音源**（`ITunesSearch.previewURL`）。確実に鳴る。完成MVは引き続き YouTube。
- **マスク基準**：曲名は「答えて解放(isUnlocked)」までマスク、**アーティスト名は常に表示**。サムネのモザイクは「フルピース集める(isComplete)まで」。`displayTitle/displayArtist`・MelodyView の blur 条件を修正。
- **出会いはすれ違った順のみ・戻れない**：「前/次の出会い」ナビと「あとで選ぶ」を撤去、出会いリストは現在の人以外ロック、表示時に `ensureActiveEncounter()` で現在の出会いへ。ピース選択後は **次の出会いへ自動遷移**、全消化で **本日のまとめ**（時刻 `🕒HH:mm`・相手・場所・曲・「この時 X/24」）。`TodayCollect` に取得時点ピース数(`ownedCountAtCollection`)＋時刻(`collectedAt`)を記録（同曲を別人で選んでも各時点の数を表示）。
- **デイリーミッション**：`9/5` 等の超過を **target上限表示**（`displayCurrent`／progress を min 1.0）。**ホームのミッションをタップで `MissionView`（新規）へ遷移**。
- **P2 メロディミックス**（`MelodyMixView`／VM `playPartnerMelody`・`playMelodyMix`）：自分＋相手（seed＝将来のメロディコード）のメロディを **ペンタ固定・音域/音色住み分けで重ねて再生**（`MelodyPlayer.playMix`）。対面接続(QR/Multipeer)前のため相手シード入力で試せる。マイページ「フォロー/フレンド」から導線。P3/P4 で実ユーザー接続＋ベスト成立に接続予定。
- **P3 すれちがい（BLE 実ユーザー交換→フォロー）**（`BLEManager` 全面改修）：iOS は manufacturer data 広告不可のため、共有サービスUUIDを広告し検出側が **GATT 接続して user_id キャラクタリスティックを read** する方式。`onNewNearby` で VM `nearbyUsers` に積み、マイページ「フォロー/フレンド」の **「すれちがった人」** からフォロー（相互でフレンド）。6時間/同一・10人/時の制限維持。要2台・前面。

### 著作権リスク低減の仕様転換（音楽SNS中心化）

- **中心体験を「今聴いてる曲の共有→出会い→ピース収集」へ**。パズルはコレクション要素に再定義。
- **公開表示を独自生成カードに統一**：`MelodyCardArtwork`（id から決定的に生成＝ジャンル色＋雰囲気色＋波形＋音符＋6×4パズル模様＋枠）。`ArtBlockView`/`PuzzlePiecesView`/`PieceSelectView` の土台を公式MVサムネ→生成カードに置換（`thumbnailURL`/`CachedThumbnail`/同梱preview.png は公開表示から撤去）。公開＝フィード/ランキング/フレンド/近距離/共有/他人のパズル候補は常に生成カード。
- **カスタム画像は本人のみ**：`customImages[trackId]`（SaveStateにbase64永続）。`PuzzleView` に PhotosPicker＋**権利・本人限定の注意文**。表示は本人の `PuzzleView`/`CollectionView` のみ（`customImage:` 明示渡し）、公開は常に nil＝生成カード。Google画像検索等の外部誘導は未実装。
- **曲名当てヒント Lv0–3**（`MysteryView` 全面改修）：Lv0=アーティスト表示＋曲名？？？＋30秒試聴（広告なし）／Lv1=ジャンル・年代・雰囲気（`genreHint`/`eraHint`/`moodHint`、広告可）／Lv2=曲名の文字が約4割開く（`maskedTitle(hintLevel:)`、広告可）／Lv3=Apple Music・iTunes確認＋曲名入力＋あとで聴く（広告なし）。**4択・「YouTube/広告で答え即解放」は撤去**（`applyHint(.answer)` は no-op）。
- **試聴・外部導線**：30秒試聴は iTunes `previewUrl`＋AVPlayer（既存）。`PreviewPlayerView`・`MysteryView`・`PuzzleView` に **Apple Music / iTunesで見る**（`ExternalMusic.openITunes` 追加）導線。**完成MV（YouTube公式埋め込み）は残しつつ**外部導線を併記（ユーザー選択）。旧 `YouTubeAudioPlayer`（音声のみ）は撤去。

### マイページ刷新・つながり一覧・アイコン変更（追補）

- **iTunes導線を全撤去** → 外部は **Apple Music＋Spotify** のみ（`ExternalMusic.openITunes` 削除）。カスタム画像の注意文も削除（ユーザー指示。本人画面のみ表示は維持）。
- **マイページ刷新**（画像準拠）：プロフィールヘッダーカードに **アイコン（タップで PhotosPicker 変更／`avatarImageData` をSaveStateに永続）＋名前＋@handle＋Lv・コイン＋EXPバー** と、**フレンド/フォロー中/フォロワーの件数バー（タップで一覧へ）＋「フレンドを追加」**を集約。`マイメロディ試聴`／`メロディミックス` は横並びボタンに。旧「フォロー/フレンド」大カード・フレンド履歴カードは撤去。
- **つながり一覧 `SocialListView`（新規・`Screen.socialList(SocialTab)`）**：件数タップ/追加ボタンから遷移。セグメント **フレンド/フォロー中/フォロワー**＋各リスト（フォロー解除/フォロー/★ベスト切替）、**フレンド内にベストフレンドを上部集約**、自分のコード・コード追加・すれちがった人もここへ集約。

### パズル画像を YouTube サムネイルに戻す（2026-10-15・はく判断）

- 著作権方針で独自生成カードに置き換えていた曲アートを、**YouTube サムネイルに戻した**。表示の優先順は「本人のカスタム画像 ＞ サムネイル（`Track.thumbnailURL`＝同梱画像→API→ytimg）＞ 独自生成カード（サムネが無い曲のみ）」。
- `MelodyCardArtwork` に `thumbnailURL` を追加。`ArtBlockView(track:)` はサムネ＋**未解放曲はモザイク**（ネタバレ防止、カスタム画像には掛けない）を復活。`PuzzlePiecesView`・`PieceSelectView` のピース切り出しもサムネに戻した。
- 生成カード（`MelodyCardArtwork` の生成部分）は、サムネの無い架空曲のフォールバックとして残置。

### Liquid Glass 対応（StyleCare の構成に合わせる・2026-10-15）

StyleCare（`StyleCareNative/src/constants/flags.js`・`TabBar.js`・`GlassSegment.js`・`GlassIconButton.js`）と同じ切り分けにした。**iOS 26 以降は OS の Liquid Glass、それ未満はぼかし素材**。真似たガラスは溶け合いや泡の動きまで届かないので、本物が無い端末で無理に再現しない。対応OSは iOS 17 のまま。

- **タブバー**：iOS 26 は OS 標準の `TabView`（`SwiftUI.Tab`。アプリ側の `enum Tab` と名前が重なるので完全修飾）。各タブが NavigationStack を持ち、画面履歴は `vm.navigationStack` 1本を「選んでいるタブにだけ」渡す。iOS 25 以下は従来の自作バーを `.regularMaterial` に。タブを移ったら `.sensoryFeedback(.selection)`。
- **`activeTab` を変えたら履歴を根本へ**（VM の didSet）。標準タブバーでは前のタブの詳細画面が別タブに残るため。副次的に、パズル画面の「ピースを集める」が詳細画面を閉じずにタブだけ変えていた不具合も直った。
- **共通部品 `Views/Components/Glass.swift`**：`mlGlass(in:)`（ガラス／ぼかし）、`GlassSegment`（ガラスの上を白いピルが滑る区分切替。コレクション・ランキング・つながりに適用）、`GlassIconButton`（iOS 26 だけ丸いガラスを敷く。マイページの編集ボタン）、`mlNavBarBackground()`（詳細画面のナビバー。iOS 26 は不透明に塗らず OS のガラスに任せる。14画面に適用）。
- 既存の不具合修正：「メロディ」タブの記号 `music.note.circle.fill` は存在しない名前で何も出ていなかった → `music.note`。マイページ「フレンドを追加」が狭い端末で3行に折り返していた → 1行固定。
- 確認：iOS 26.3（iPhone 17 Pro）で標準のガラスタブバー、iOS 18.4（iPhone 16 Pro Max）で自作バーに倒れることをシミュレーターで確認。iOS 26.3 シミュレーターだけカラー絵文字が「?」になる（フォントはあり、同じコードが 18.4・実機では出る）。シミュレーター側の表示不具合とみて未対応。

### スクロール追従ヘッダー（StyleCare の HomeScreen と同じ作り・2026-10-15）

- 共通枠 `Views/Components/TabScreen.swift`（`MLTabScreen`）：ヘッダーを中身の上に重ね、**上段は下へ送ると隠れ、上へ戻すと出る／pinned は上端に残す**。中身の余白（`contentMargins`）は上段を隠しても変えない（変えると中身が跳ねてスクロール量の判定が揺れる）。
- ぼかし（`.bar`）は中身がヘッダーの下に潜っているあいだだけ出す。スクロール量を測れるのは iOS 18 以降（`onScrollGeometryChange`）なので、iOS 17 は上段を隠さず、ぼかしは常に出す。
- 隠すのは**中身が上段の高さを越えて流れてから**（早く隠すと上段が抜けた所に空白の帯が見えた）。下端での跳ね返りは「上へ戻した」と数えない。
- 各タブ：ホーム＝上段プロフィール行（マイページで設定したアイコンを表示）／pinned レベルバー（StyleCare の LevelBar と同じ役）。メロディ・マイページ＝上段見出し。コレクション＝上段 見出し＋検索／pinned 区分切替。ランキング＝上段 見出し／pinned 区分切替。
- ついでに：コレクションの「完成済み」枠が空のとき幅が狭く中央寄せになっていたのを横幅いっぱいに。
- 確認：iOS 26.3・iOS 18.4 のシミュレーターで、隠れる／残る／ぼかし／空白なしを確認。

### フレンドを「申請 → 承認」へ・マイページを StyleCare の並びに（2026-10-15）

**決定（はく）**：フレンドは StyleCare の仲間と同じ「申請して、相手が承認したら成立」に一本化。フォロー／フォロワーはやめる。推し曲は今の形（推し曲＝アプリ内の曲で相手に届く／好きな曲＝プロフィールで自由）を維持。音楽サービスの公式アイコンは はく が各社のブランド素材ページから用意する。

- **サーバー**：`supabase/migrations/20261015120000_friend_requests.sql`（**未適用**。MelodyLien の Supabase が一時停止中のため）。`friend_links`（requester / addressee / status pending|accepted。`friendships` はすれ違いの交換履歴の名前で使用中なので別名）＋`friend_bests`。RLS：申請は自分から・待ちでしか入れられない／承認は受けた側だけ／取り消し・断る・解除はどちらからでも。2人が同時に申請し合ったら待たずに成立（StyleCare 20260916 と同じ）。承認時刻はサーバーで入れる。解除でベスト指定も消す。`find_user_by_handle`・`get_display_names`（返すのは表示名とIDだけ）。相互フォローだった人はフレンドとして引き継ぎ（follows は消さない）。
- **アプリ**：`SupabaseClient` のフォロー API を申請・承認・解除・ベストに置き換え。VM は `friendList`（フレンド／届いた申請／送った申請）。
- **画面（StyleCare と同じ作り）**：`FriendsView`（フレンド／届いた申請の小タブ、行は1枚ずつのカードにしない、「…」からベスト指定・解除）、`FriendAddView`（自分の情報と招待 → ユーザーIDで申請 → 公開の設定）、`InviteCardView`（QR 名刺。右上のカメラで相手の QR を読む＝VisionKit。自分たちの招待リンクしか受けない）、`NearbyFriendsView`（Bluetooth で近くの人を並べて申請）、`InvitePersonSheet`（招待リンク・QR から開いたとき。関係で押すものを変え、申請は自動で送らない）。招待リンクは既存の URL スキームを流用：`com.streetmelody.app://invite/<ユーザーID>`。カメラの許可（`NSCameraUsageDescription`）を追加。
- **マイページ**：StyleCare の並び（プロフィールカード：写真・名前「変更」・@ID＋写す・フレンド数・QR → 小見出し＋1項目1枚のメニュー → 契約 → アカウント → アプリについて）。フレンドはメニューの1項目で、申請が届いていると数のバッジ。
- **「?」の解消**：iOS 26.3 シミュレーターでカラー絵文字が「?」になっていた所（アイコン未設定の🎵・コインの🪙・音楽サービスの🎵）を記号に置き換え（`UserAvatar`・`CoinIcon`・`ServiceIcon`）。音楽サービスは `Resources/ServiceIcons/service_*.png` を置けば公式アイコンに差し替わる（README あり）。
- 旧「すれ違った相手の交換履歴」画面（`FriendsView`）は前回のマイページ刷新で入口が無くなっていたので、新しいフレンド画面に置き換えた（旧版は git 履歴にある）。

### DB を StyleCare のプロジェクトへ移す（共通アカウント・2026-10-15・はく判断 C）

旧 MelodyLien プロジェクト（wngtvdgzzlkajtbwsurc）が無料プランの上限で停止していたため、DailyBasket（`shopping`）・Life_LevelUP（`lifelevelup`）と同じく **StyleCare のプロジェクト（oaurexinrtvzvtvotqaw）に `streetmelody` スキーマで同居**した。

- **適用済み**：`supabase/migrations/20261015130000_streetmelody_schema.sql`。`profiles`（アプリ固有：好きなアーティスト・曲、誕生日、性別、公開範囲、コイン）／`collected_pieces`／`unlocked_tracks`／`hint_levels`／`exchange_history`（旧 friendships＝すれ違い相手との交換履歴）／`now_playing`（公開・フレンド・ベストを RLS で判定）／`friend_links`・`friend_bests`。全表 RLS ＋「匿名は書けない」を RESTRICTIVE で重ねた。auth.users へのトリガーは足さない（全アプリの登録に効くため）。旧 `supabase/migrations/20261015120000_friend_requests.sql`（旧プロジェクト向け・未適用）は削除。
- **名前・ユーザーID・ひとことは共通の `public.profiles`**。ID の変更は `public.change_handle`（変更の間隔・重複・最近手放されたIDを見る）、空き確認 `public.is_handle_available`、検索 `public.find_user_by_handle`、名前のまとめ取得 `public.get_display_names`（アイコンURLも返る）。ID の決まりも共通に合わせた（半角英数字と - _、1〜16文字）。
- **ログイン**：匿名ログインをやめた（このプロジェクトでは止めてある）。未ログインのあいだは端末の中だけで動き、フレンドには「ログインが要ります」を出す。ログインはメール（新規登録は確認メールあり）と Google。Apple・Spotify のログインはこのプロジェクトで無効なのでボタンを外した（Spotify の「今聴いてる曲」連携は別物で残る）。保存場所を変えたので旧プロジェクトのログインは引き継がない。端末の進行はログイン後の同期で上がる。
- **通信**：全 REST に `Accept-Profile` / `Content-Profile`（既定 `streetmelody`、共通の名前・ID は `public`）。ログインの鍵（1時間）が切れたら1回取り直して再送。ログアウトですれちがいの発信も止める（`BLEManager.stop`）。
- **検証**：DB の中で既存の2人のつもりで申請・承認を試し、最後に全部取り消すテストで12項目を確認（申請した側は承認できない／いきなり承認済みは拒否／フレンド前のベストは拒否／受けた側の承認で成立／フレンド限定の曲はフレンドだけ読める／他人の申請は見えない／お互いに申請したら成立／解除でベストも消える ほか）。安全チェック（advisors）に `streetmelody` の指摘なし。
- **残り（はくのダッシュボード作業）**：① Settings → API → Exposed schemas に `streetmelody` を足す（これが無いとアプリから読めない）② Authentication → URL Configuration → Redirect URLs に `com.streetmelody.app://login-callback`（Google ログイン用）。
- **未移行**：曲カタログ（`artists` / `tracks`）。Go サーバーは旧プロジェクトから読めないので内蔵の見本で動いている。移すには Go の接続先変更と Cloud Run への再デプロイが要る。

### 見た目の奥行き・音楽サービスでのログイン（2026-10-15）

- **奥行きの仕組み** `Views/Components/Theme.swift`：影を2枚重ね（足元の短く濃い影＋広く淡い影、色はアプリの紫を暗くした色）。`mlCard`（上が光る縁＋白→淡紫の面＋影。HomeView の拡張から移した）、`mlInset`（カードの中の小さなマスを少しくぼませる）、`mlGlow`（主ボタンの色付きの光）、`MLBackground`（一枚色をやめ、上に紫とピンクの淡いにじみ）。背景は17か所を置き換え。主ボタン・試聴ボタン・共通のボタン部品に光、メニューのアイコンにグラデーションと白い縁、曲のジャケットに軽い影。
- **ログイン**：共通プロジェクトで有効なログイン方法を `/auth/v1/settings` から読み、押せるボタンを決める（無効なまま押して失敗しない）。Spotify のボタンを戻した（有効化されたら自動で押せる）。Google は「YouTube Music」と併記。Apple は有料の開発者登録が要るので出さない。
- **確認**：Exposed schemas に `streetmelody` が入った（未ログインでの読み取りは 42501＝権限なし、が正しい）。シミュレーターで共通アカウントにログインでき、名前「はく」・自動で振られた ID が共通の public.profiles から読めた。

### いまのアカウントにログイン方法を足す（2026-10-15）

- マイページ「アカウント」に **ログイン方法**（メール・Google（YouTube Music）・Spotify）。使えるものは「使えます」、共通プロジェクトで有効だがまだ紐付いていないものは「追加」。追加は Supabase の手動連携（`/auth/v1/user/identities/authorize`、PKCE）で、名前・ID・進行はそのまま。いまのアカウントのログイン方法は `/auth/v1/user` の identities から読む。
- 連携できない理由を分かる言葉に（サーバーで手動連携がオフ／そのログイン方法が別のアカウントで使われている）。ログイン画面を自分で閉じたときは「キャンセルしました」だけ出す（以前は技術的なエラー文が出た）。
- 確認：Spotify の「追加」で Spotify のログイン画面まで開く（＝手動連携はオン）。ログインそのものは本人が行う。
- メモ：作業中にリポジトリのフォルダが `Life-os/MelodyLien` → `Life-os/StreetMelody` に変わった（中身・履歴は同じ）。

## 2026-10-15 — Web UI のパステルデザイン統合

- 承認済みの独立試作から生成イラスト2点を `apps/web/assets/pastel/` へ取り込み、ホームとログインに採用。
- `apps/web/src/pastel.css` に共通デザイントークン、立体カード、ボタン、タブ、下部ナビ、モーダルをまとめた。パズル画像・ストア・認証処理は維持。
- ホームを実データのコレクション進捗、今日のメロディ、出会い通知、デイリーミッションで構成。900px以上はサイドナビと2列レイアウト、スマホは下部5タブ。低い画面とsafe-areaにも対応。
- 詳細画面の親タブ選択と `aria-current`、キーボードフォーカス、reduced-motionを整備。完成・称号獲得の配色もパステルへ統一。
- 対象は Web 本体。iOS / Android のネイティブ画面は今回変更していない。

検証:
- `GOCACHE=/private/tmp/streetmelody-go-cache npm run check` 成功（JS構文・Goビルド）。
- `npm run test:store` は経験値の期待値で失敗。HEADのテスト・data.js・store.jsを一時ディレクトリに取り出した変更前の実行でも同一箇所で失敗することを確認。
- ブラウザでローカルゲスト開始、ホーム→メロディ→ピース選択、コレクション→曲パズル、ランキング、マイページ→通知設定を確認。390pxと1280pxで横方向のオーバーフローなし。最終コンソールエラーなし。
- スクリーンショット: `docs/ui/pastel-mobile.png` / `docs/ui/pastel-desktop.png`。

## 2026-10-15 — SwiftUI / Jetpack Compose へのパステルデザイン展開

- iOS: `MLPalette` と既存の `mlCard` / `mlInset` / `mlShadow` をクリーム・ラベンダー・ピンク・ハニーの共通トークンへ統一。各画面の既存の紫色・文字色も合わせた。プロフィール・再生・BLE・認証・報酬ロジックは維持。
- iOS: ホームに `MLWelcomeHero` と新しい発見バナーを追加。集計カードを3色に分け、既存の曲アートと進捗を保持。大きいアクセシビリティ文字サイズではヒーローを縦に配置。iOS 26の標準タブは維持し、それ以前のカスタムタブにも配色を適用。
- iOS: `Resources/Pastel.xcassets` に生成済み素材を登録。XcodeGenでプロジェクトを再生成し、iPhone 17 Pro / iOS 26.3でホーム表示を確認。`docs/ui/pastel-ios.png` に保存。
- Android: `MelodyColors` / `PastelCard` / `PastelButton` / `WelcomeHero` を整備。ホーム・パズル・下部ナビ・起動テーマに共通デザインを適用。素材は `drawable-nodpi` に登録。
- Android: 元々未実装だった交換・アーティスト・プレイリストの3タブは、機能を実装済みに見せず、同じデザインの準備中案内へ変更。
- Android: ビルドに欠けていたversion catalog、Wrapper、AndroidX設定、テーマ・ランチャーリソースを補完。`gradle/libs.versions.toml` とGradle 8.14.3で再現できる構成にした。

検証:
- iOS: `xcodebuild -project apps/ios/StreetMelody.xcodeproj -scheme StreetMelody -sdk iphonesimulator -configuration Debug -derivedDataPath /private/tmp/streetmelody-pastel-ios CODE_SIGNING_ALLOWED=NO build` 成功。最終デザインコードのコンパイル済み。シミュレータ用、実機署名は未検証。
- Android: `ANDROID_HOME=/Users/to_fu/Library/Android/sdk apps/android/gradlew -p apps/android :app:assembleDebug` 成功。APK: `apps/android/app/build/outputs/apk/debug/app-debug.apk`。
- Androidの実画面確認は未完了。既存AVD `Medium_Phone_API_36` がホスト空き容量不足で起動を拒否したため。ユーザーデータの削除などは行っていない。
- `git diff --check` 成功。

## 2026-10-15 — オリジナルの小鳥ヒーロー画像へ差し替え

「いつもの道に、新しいメロディ。」の画像を、参考画像を入力せずに新規生成した小鳥のアートへ置換。ラベンダーのヘッドホンをつけたミント色の小鳥が、音符・パズルピースと一緒に街を歩く構図。Web本体・独立試作・SwiftUIのPastelHero・Composeのpastel_heroへ同一画像を組み込み、Webの代替テキストも更新。生成ツールはbuilt-in image_gen。正確なプロンプトは `apps/web/assets/pastel/hero-generation.md` に保存。

差し替え検証: iOSシミュレータ用ビルドとAndroid assembleDebugが成功。iOSシミュレータへ更新版をインストールして再起動し、ホームに小鳥画像が表示されることを確認。確認画像は `docs/ui/original-bird-web.png` / `docs/ui/original-bird-ios.png`。

## 2026-10-15 — ヒーローのメロディボタンを画像に調和

Web・SwiftUI・Composeのヒーロー専用CTAを、クリーム色の陶器風ピル・ラベンダーの音符バッジ・細い縁・柔らかな接地影へ変更。一般の主要ボタンのデザインは維持。Webは文字の折り返しと画像内の余白も調整し、メロディ画面へ遷移することを確認。iOSシミュレータビルド、Android assembleDebugとも成功。画面は `docs/ui/hero-ceramic-button.png`。

## 2026-10-15 — モバイルの初回体験・完成間近の導線・Android主要画面

Webは変更せず、SwiftUI / Compose のみを対象に実装。

- 両OS: 初回の3ステップ案内、スキップ、完了の端末保存、ホームからの再表示。
- 両OS: 未着手・完成済み・不正な総数を除外し、完成率順で最大2曲をホームに表示。現在選べる未所持の候補がある場合だけ「集める」、なければ「見る」。未解放曲の曲名はマスクを保持。
- iOS: すれちがいの順番とクールタイムを尊重し、現在の出会いに対象ピースがあればその候補へ進む。なければ既存のパズル／未解放曲の詳細へ。
- Android: 交換候補の選択・所持状態・取得確認・二重送信防止・結果詳細を接続。コレクションから選択した曲の詳細、アーティスト別の進捗と曲一覧、今日のプレイリスト、ヒント／曲名解放、戻る操作を実装。旧来の「準備中」タブは撤去。
- Android: 読み込み、部分的な通信失敗、再試行、HTTPエラー、タイムアウトを扱う。受け取り後はサーバーから進捗・報酬・集計を再取得。Debugのみエミュレータホスト／ループバックへのHTTPを許可し、Releaseは変更なし。
- Android: 実データの9ピースに対して24マス固定だった不整合を修正。24ピースは6×4、それ以外は総数に合わせたグリッド。

検証:
- iOSシミュレータ向けビルド成功。iPhone 17 Pro / iOS 26.3で、案内の3段階とメロディへの遷移、アプリ再起動後の完了保持、完成間近の曲から詳細への遷移を確認。
- Android `:app:assembleDebug :app:testDebugUnitTest :app:connectedDebugAndroidTest` 成功。単体テスト6件、エミュレータ計測テスト1件、失敗0。計測テストは隔離したローカルAPIのテストデータを使用し、ピース取得→詳細→アーティスト→プレイリスト→コレクション→ホームを検証。
- 同じローカルAPI契約の検証で、候補の不正なindexが400となること、同じピースの再取得でadded=falseとなることを確認。
- 以前は容量不足だったAndroid AVDも空き容量の変化後に起動可能となり、Androidの実画面も確認できた。
- プレビュー: `docs/ui/discovery-guide-ios.png` / `discovery-progress-ios.png` / `discovery-guide-android.png`。
- `git diff --check` 成功。

残る範囲: BLEの実機同士・バックグラウンド動作、広告／課金の本番連携、Androidの認証済みユーザー別データ連携は今回の画面実装とテストには含めていない。Androidのヒント／解放は既存の試作APIを使用。Webストアの既存の経験値テストは、モバイルのみという指示に従い変更していない。

## 2026-10-15 — iOS のサムネを 16:9 に

正方形で切っていた曲のサムネを、YouTube と同じ 16:9 に統一。

- `ArtBlockView.ratio`（16:9）と `mlThumbFrame(width:)` を足し、一覧の行は横長（80×45 が基本。プレイリスト 72、マイページの推し曲 64）、ホームとプレイリストの「今日のメロディ」は 152×86 にした。
- グリッドは 3列の正方形 → 2列の 16:9（ホームの最近届いた曲は 3曲 → 4曲、コレクションの完成済み・アーティスト・推し曲、フレンド詳細）。
- サムネの出どころを「同梱画像 → YouTube」から「YouTube の maxresdefault → 同梱画像」に入れ替えた。同梱画像（Web 版のパズル見本）は 6×4 の線と黒帯が焼き込まれ、横に伸びていて、16:9 の枠だとそのまま見えるため。maxres の無い動画は hqdefault に落とす（4:3 の黒帯は 16:9 の中央クロップで消える）。
- MV そのものの黒帯（シネスコの上下・額縁）は、読み込み時に切り落とす（`UIImage.trimmingBlackBars()`。行・列のほぼ全部が真っ黒のときだけ。1辺あたり最大 25%）。
- iOS シミュレータ（iPhone 17 Pro / iOS 26.3）でホーム・コレクション（曲パズル・アーティスト）・パズル画面を確認。

残り: オフラインでは YouTube のサムネが読めず、まだ読んだことのない曲は生成カードになる（以前は同梱画像だった）。

## 2026-10-15 — すれちがいを人生の記録（共通ハブ）へ送る（Life_LevelUP のセッションが作成）

コミット `85ecd84`（DB・中継）と `b3cf46d`（iOS）。

- DB: `streetmelody.encounter_days`（送る待ち）と関数4つ。相手は小文字にした uid の sha256 先頭12文字だけを持つ。同じ人・同じ日（JST）は1件。実在しない相手（auth.users に無い）は断る。表への GRANT は無く、口は関数だけ（端末が送った印を自分で打てないように）。本番に適用済み（`20261015170000`・`20261015180000`）。
- 中継: `workers/`（Cloudflare Worker、streetmelody-relay）。本人のトークンを確かめ、DB に入れてからハブへ流す。**ハブの鍵が入るまでは DB に溜まるだけ**。
- iOS: `Services/LifeEvents.swift`。数えるのは `BLEManager.record` の口だけ（アプリ内のメロディの出会いは見本の架空の人なので送らない）。届くまで端末に控えを残し、BLE の開始時と前面に来たときに送る。
- 控えの持ち主: 当初は持ち主が無く、ログアウト後に別の人がログインすると前の人のすれちがいが次の人の記録として送られた。`064f478` で、控えに持ち主（小文字の user_id）を持たせ、いまログインしている人のぶんだけを送るように直した（送る直前に SupabaseClient の中でも確かめる。保存の鍵は v2）。iOS にテストのターゲットが無いので、この振り分けは検査で固定できていない。実機2台での確認もまだ。

## 2026-10-15 — モバイルの他タブをホームのデザインへ統一

Webは変更せず、iOS / Androidの既存タブを対象に整えた。

- 共通: 英文の小見出し、ラベンダーのアイコンタイル、クリームの立体カード、ピンク・ラベンダーの集計タイルを採用。
- iOS: メロディに受け取り可能な出会い／今日の取得数、コレクションに総ピース／完成曲、ランキングに順位／総ピース、マイページに推し曲／完成曲／承認済みフレンド数を追加。タブ切替の選択ピル、検索欄、曲リスト、順位バッジを統一。メロディの文字化けしていた絵文字はSF Symbolsに置換。
- iOS: コレクション検索も表示可能な曲名・アーティスト名を対象にし、未解放曲の内部の曲名で検索結果が漏れないようにした。
- Android: 届いたメロディ／曲パズル／アーティスト／プレイリストに共通の導入・集計カードを追加。候補の選択枠と主要ボタン、曲一覧の矢印、アーティストのアイコンをホームと揃えた。読み込み・既存の遷移・操作中の無効化は維持。
- iOS UIテストで4つのタブへの遷移を確認し、実画面の添付画像を保存する仕組みを追加。Androidの既存の画面遷移テストにも各タブのスクリーンショット保存を加えた。
- 検証: iOS Simulatorでビルド・4タブのUIテストが成功（1件、失敗0）。Androidはビルド・単体テスト6件が成功。Gradleの端末テストはAPK転送に失敗したため、同じAPKとテストAPKをadbの非ストリーミング方式でインストールし、AndroidJUnitRunnerで直接実行して成功（1件、失敗0）。ピース選択・受け取り・アーティスト詳細・各タブへの移動を確認。
- プレビュー: `docs/ui/tabs-{melody,collection,ranking,mypage}-ios.png` と `docs/ui/android-tabs-capture/tabs-{exchange,collection,artists,playlist}-android.png` にシミュレータ／エミュレータの実画面を保存。実機での確認は未実施。

## 2026-10-15 — モバイルのボタンに長押し中のフィードバックを追加

- iOS: 共通の `MLPressButtonStyle` と `MLPressFeedback` を追加。これまでplainだったボタン、アイコン、セグメント、曲リストに適用し、メインボタンとヒーローボタンも統一。押している間は縮小・2ptの沈み・濃淡変化を維持し、主要ボタンの影を弱める。視差効果を減らす設定では縮小・移動・アニメーションを止め、色の変化で示す。
- Android: `MutableInteractionSource` の押下状態を共用して共通ボタン、ヒーロー、曲や候補のクリック領域に縮小・2dpの沈み・透明度の変化を追加。主要ボタンの影も弱める。標準Materialボタンやタブは標準の押下表示を維持。
- 長押し専用のアクションは追加せず、標準のタッチ処理を利用。指を離して確定、スクロールやキャンセル時には押下表示を戻す。
- 検証: iOS / Androidのビルド成功。iOS UIテストでボタンの外へドラッグしてキャンセルした後、5秒長押しして離すと遷移することを確認（1件、失敗0）。通常時・長押し中の実画面は `docs/ui/press-resting-ios.png` / `docs/ui/press-held-ios.png`。
- Androidの長押しテストも追加したが、今回のエミュレータはSystem UIの応答停止ダイアログが表示され、ActivityScenarioの終了処理でタイムアウトした。操作検証の成功とは扱わない。比較用プレビューは検証できたiOSの実画面からボタン部分を切り出した `docs/ui/press-button-{resting,held}-ios.png` を使用。

## 2026-10-22 — 曲カタログを共通プロジェクトへ（準備まで）・音楽サービスのアイコン

- 古い MelodyLien プロジェクトは無料プランの上限（同時に2つ）で起こせないため、当時 MCP で入れた記録（8組・8曲）から `supabase/migrations/20261022120000_streetmelody_catalog.sql` を作った。中身は iOS の seed と一致。サムネは YouTube の maxresdefault を引き金で作る（当時と同じ）。
- カタログを Go サーバー（公開キー＝anon）に読ませるため、anon に `streetmelody` スキーマの USAGE を渡す。代わりに関数の PUBLIC の EXECUTE を外し（これから作る関数も既定で外す）、anon が触れるのはカタログ2表の SELECT だけにする。引き金は EXECUTE が無くても動くことを手元で確かめた。
- 検査: `supabase/tests/02_catalog_checks.sql` を足した。`run.sh` は最後の1本の結果しか見ていなかった（`if run_all` の中では set -e が効かない）ので、1本ずつ失敗で抜けるように直した。守りを壊す検査 21件はすべて赤。
- （後で変えた）最初は anon に読ませる形で作ったが、はくの判断で「アプリはログイン必須」になったので、ログインした人だけ読める形に作り直してから本番に当てた（下の節）。
- Go: `streetmelody` スキーマを Accept-Profile で読む（`SUPABASE_SCHEMA`、既定 `streetmelody`）。接続先を StyleCare のプロジェクトへ。`api/store/supabase_test.go`。Cloud Run への出し直しは、本番の DB に当ててから。
- 音楽サービスの公式アイコン（はくが用意）を `Resources/ServiceIcons/` へ。YouTube Music の画像は中身が JPEG だったため PNG に変換した（そのままだとビルドで落ちる）。マイページで3つとも表示を確認。

## 2026-10-22 — 設定を StyleCare と同じ形に・Google の印

- マイページの歯車は、これまでプロフィールの編集を開いていた。StyleCare と同じく「設定」のシート（`Views/Screens/SettingsView.swift`）を開くようにした。並びは StyleCare と同じで、見出しの「設定」と閉じる、「アカウント」（ログイン中のメール・ログイン方法と「追加」）、「アプリについて」（利用規約・プライバシーポリシー・ログアウト）。ログアウトは赤で、確かめてから。
- 名前・ID・ひとことの編集は、StyleCare と同じくプロフィールのカード（名前の「変更」）から。マイページにあったアカウントの節・ヘルプ・規約・版は設定へ移した。右上は StyleCare と同じく「フレンドを追加」と歯車。この2つと見分けがつかないので、マイページでは見出しの飾りの絵を出さない（`MLTabTitle(showsSymbol:)`）。
- ログイン方法の Google は、YouTube Music の絵をやめて、StyleCare のログイン画面と同じ公式の G（`Resources/Brand.xcassets/google_g`。SVG をベクターのまま）。ログイン画面のボタンも「Google で続ける」にし、白地に薄い枠（StyleCare と同じ #E5E7EB）。
- YouTube Music のアイコンは外側の白だけを透過にした（四隅から塗りつぶし。円の中の白い輪と再生マークは残す）。
- 未対応: アカウントの削除。StyleCare の設定にはあるが、共通アカウントの削除は StyleCare の Worker（/api/account/delete）が StyleCare 専用の鍵で受け持つため、StreetMelody からどう呼ぶかを決めてから。

## 2026-10-22 — 取得可能なピースを「？」で・今日のメロディのプレゼント（3D の開封演出）

- ピースを選ぶ画面: 取得可能と取得不可が、どちらも淡い紫で見分けにくかった。取得可能は紫→ピンクのグラデーションに大きな白い「？」で、ゆっくり光る（視差効果を減らす設定では止める）。取得不可は灰色に小さな鍵。凡例も同じ印にした（`AvailablePieceMark` / `UnavailablePieceMark`）。メロディ画面の候補のパズルにも、その出会いで取れるピースを同じ「？」で出す（`PuzzlePiecesView(availablePieces:)`。フル表示のときは出さない）。
- 今日のメロディが届いていて、今日まだ開けていなければ、読み込みのあと1日1回プレゼントの演出を出す（`Views/Components/MelodyGiftOverlay.swift`、`vm.melodyGiftCount`）。プロフィールの登録やパズル完成の演出が出ているときは、閉じてから。
  - 箱は SceneKit（OS 内蔵の 3D。追加の部品なし）。水玉と音符の包み紙・金のリボンとちょう結び・影。上から落ちて弾み、ゆっくり回る。押すと（押さなくても約2.6秒で）震えてためを作り、ふたが回りながら飛んで、箱の中から光・紙吹雪（5色）・きらめき・音符が出る。開いたあとも音符がゆっくり昇る。
  - 後ろに回る光の筋、背景のきらめき、「◯件のメロディが届きました！」の数え上げ（1つずつ触覚）、「メロディを受け取る」（メロディのタブへ）と「あとで」。触覚は着地・震え・ふた・数え上げ。
  - 「視差効果を減らす」の人には、動かさずに結果だけを出す。
  - 確かめ方: 録画（`simctl io recordVideo`）からコマを抜いて確認。明るすぎる点がブルームで黒い四角に化けた・きらめきが重なって白い雲になった・震えのあいだ光の円が箱の前に残った、の3つを直した。
  - 試すとき: その日の印 `streetmelody.melodyGift.lastDay` を消すと、もう一度出る。

## 2026-10-22 — アプリをログイン必須に・曲カタログを本番へ

はくの判断: 「ログインしていないと使えないように」＝アプリ全体（StyleCare と同じ）。

- 起動するとまず保存済みのログインで復帰し、確かめ終わるまでは起動画面（`LaunchCover`）。ログインしていなければ、ログイン／新規登録の画面を全面に出して閉じられない（`AccountLinkView(asGate: true)`。アプリ名とひとことを上に）。ログアウトするとこの画面に戻る。
- 起動時に圏外だっただけでログアウト扱いにしていた（更新の鍵の取り直しが通信で失敗すると signOut していた）。サーバーが断ったとき（4xx）だけ未ログインに戻し、通信できないときは本人のまま入れて、鍵は次に通信するとき取り直す（`hasSession` / `ensureAccessToken`）。ログイン必須にすると、圏外で閉め出してしまうため。
- 曲カタログ: `20261022120000_streetmelody_catalog.sql` を「ログインした人だけ読める」形にして本番に当てた。anon はこれまでどおりスキーマごと入れない。本番で 8組・8曲・サムネは maxres、anon は USAGE も SELECT も無し、authenticated は読むだけ、既存の引き金が動くこと（取り消す形で）を確かめた。手元の検査は通常2本と、守りを壊す 22件すべて赤。
- iPhone はカタログを Go サーバーではなく DB から本人の鍵で直接読む（`catalogThumbnails`。読めたことを本番のログで確かめた）。
- Go サーバー（Android・Web が使う）は本人がいないので、読むにはサーバー用の秘密の鍵が要る（`SUPABASE_SECRET_KEY`。デプロイスクリプトは Secret Manager の `streetmelody-supabase-secret` があれば渡す）。入れるまでは埋め込みの見本で動く（今と同じ）。Cloud Run の出し直しは鍵を入れてから。
- 今日のプレゼントの演出は、ログインしてから出す。
- 開発用: 起動引数 `-previewLoginGate` で、ログアウトせずにログイン画面を見られる（DEBUG だけ）。
- 確かめたこと: ログイン済みでは起動画面からそのままホームへ（ログイン画面は出ない）。ログイン画面の見た目（上の引数で）。
