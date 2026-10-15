import Foundation
import CryptoKit

// MARK: - SupabaseClient
//
// 方式A（クライアント直結）の基盤。
// Supabase Auth（GoTrue）でサインインして JWT を得て、以後 per-user データを
// Supabase（PostgREST）に直接読み書きするための最小クライアント（REST・URLSession ベース）。
//
// - 接続先は StyleCare のプロジェクト（共通アカウント。2026-10-15 に MelodyLien から移った）。
//   StreetMelody のデータは `streetmelody` スキーマ、名前・ユーザーID・ひとことは
//   共通の `public.profiles`（ID の変更は public.change_handle）。
// - 匿名ログインは使わない（エコシステムの約束。プロジェクト側でも止めてある）。
//   ログインしていないあいだは、アプリは端末の中のデータだけで動く。

actor SupabaseClient {
    static let shared = SupabaseClient()

    // 公開（publishable / anon）キー。秘密ではない。
    nonisolated let baseURL = "https://oaurexinrtvzvtvotqaw.supabase.co"
    nonisolated let anonKey = "sb_publishable_JuWP6MzIP_zeWDGsoQLwAA_flKbS71V"

    /// StreetMelody のデータを置くスキーマ（共通の名前・ID は public）
    nonisolated static let appSchema = "streetmelody"

    private let session: URLSession
    // 旧プロジェクトのセッションは新しいプロジェクトでは使えないので、保存場所ごと分ける
    private let sessionKey = "streetmelody.supabase.session.v2-common"

    private(set) var userId: String?
    private(set) var email: String?
    private(set) var isAnonymous: Bool = false
    private var accessToken: String?
    private var refreshToken: String?

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 8     // 1リクエストの上限（体感速度優先）
        cfg.timeoutIntervalForResource = 15   // 全体上限（暴走待ち防止）
        cfg.waitsForConnectivity = false      // 不通時は即失敗（UIを待たせない）
        session = URLSession(configuration: cfg)
    }

    /// シミュレータ等で間欠的に出る HTTP/3(QUIC) の -1005「接続喪失」を吸収するため、
    /// 接続喪失時のみ短く2回だけリトライする（待ち時間を抑える）。
    private func dataWithRetry(_ req: URLRequest, attempts: Int = 3) async throws -> (Data, URLResponse) {
        var r = req
        r.assumesHTTP3Capable = false   // QUIC(HTTP/3)を前提にしない＝シミュレータの-1005を緩和
        var lastError: Error = URLError(.unknown)
        for _ in 0..<attempts {
            do { return try await session.data(for: r) }
            catch let e as URLError where e.code == .networkConnectionLost {
                lastError = e
                try? await Task.sleep(nanoseconds: 150_000_000)   // 0.15s 固定
            }
        }
        throw lastError
    }

    // MARK: Session model

    private struct AuthSession: Codable {
        let access_token: String
        let refresh_token: String
        let user: AuthUser
    }
    private struct AuthUser: Codable {
        let id: String
        let email: String?
        let is_anonymous: Bool?
    }
    private struct SavedSession: Codable { let refreshToken: String; let userId: String }

    var isSignedIn: Bool { userId != nil && accessToken != nil }

    enum AuthError: Error { case notSignedIn, http(Int) }

    // MARK: Bootstrap / sign-in

    /// 起動時に呼ぶ。保存済みセッションがあれば更新トークンで復帰する。
    /// 無ければ未ログインのまま（匿名ログインはしない）。
    func bootstrap() async {
        guard let saved = loadSaved() else { return }
        if (try? await refresh(saved.refreshToken)) == nil {
            // 期限切れ・取り消し済み。未ログインに戻す
            signOut()
        }
    }

    /// メール＋パスワードでサインイン（別端末・再インストール後の復元に使う）。
    @discardableResult
    func signInWithEmail(_ email: String, _ password: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let data = try await authRequest(method: "POST", path: "/auth/v1/token?grant_type=password", body: body)
        return try apply(data)
    }

    /// メールで新規登録（共通アカウント）。
    /// 戻り値: すぐログインできたか（false＝確認メールを送った。リンクを押してからログイン）。
    @discardableResult
    func signUpWithEmail(_ email: String, _ password: String) async throws -> Bool {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let data = try await authRequest(method: "POST", path: "/auth/v1/signup", body: body)
        // 確認メールが要る設定では、セッションは返らずユーザーだけが返る
        if (try? JSONDecoder().decode(AuthSession.self, from: data)) != nil {
            try apply(data)
            return true
        }
        return false
    }

    /// いまのアカウントで使えるログイン方法（"email" / "google" / "spotify" …）。
    func linkedProviders() async -> [String] {
        func fetch() async -> (Int, Data)? {
            guard let token = accessToken, let url = URL(string: baseURL + "/auth/v1/user") else { return nil }
            var req = URLRequest(url: url)
            req.setValue(anonKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            guard let (data, resp) = try? await dataWithRetry(req) else { return nil }
            return ((resp as? HTTPURLResponse)?.statusCode ?? 0, data)
        }
        var res = await fetch()
        if res?.0 == 401, let rt = refreshToken, (try? await refresh(rt)) != nil { res = await fetch() }
        struct U: Decodable { struct I: Decodable { let provider: String }; let identities: [I]? }
        guard let (code, data) = res, (200..<300).contains(code),
              let u = try? JSONDecoder().decode(U.self, from: data) else { return [] }
        return Array(Set((u.identities ?? []).map(\.provider))).sorted()
    }

    /// 共通アカウントのプロジェクトで有効なログイン方法（"google" / "spotify" など）。
    /// ログイン画面は、ここに入っているものだけを押せるようにする（無効なまま押して失敗しないように）。
    func enabledProviders() async -> Set<String> {
        guard let url = URL(string: baseURL + "/auth/v1/settings") else { return [] }
        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        guard let (data, _) = try? await dataWithRetry(req),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ext = obj["external"] as? [String: Any] else { return [] }
        return Set(ext.compactMap { k, v in (v as? Bool) == true ? k : nil })
    }

    func signOut() {
        accessToken = nil; refreshToken = nil; userId = nil; email = nil; isAnonymous = false
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    // MARK: OAuth（PKCE・REST 直叩き。SDK のネットワークを使わずシミュレータでも動く）

    private var pendingVerifier: String?
    private let oauthRedirect = "com.streetmelody.app://login-callback"

    /// プロバイダの認可URLを返す。link=true は今の（匿名）セッションに紐付け（昇格）、false は新規サインイン。
    func oauthAuthorizeURL(provider: String, link: Bool) async throws -> URL {
        let verifier = Self.pkceVerifier()
        pendingVerifier = verifier
        let challenge = Self.pkceChallenge(verifier)
        let items = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: oauthRedirect),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
        ]
        if !link {
            // 新規サインイン: /authorize を直接ブラウザで開く（302 連鎖でプロバイダ→コールバック）
            var comps = URLComponents(string: baseURL + "/auth/v1/authorize")!
            comps.queryItems = items
            guard let u = comps.url else { throw AuthError.notSignedIn }
            return u
        }
        // 昇格: 認可URL取得には Bearer が要る（ブラウザはヘッダ送れない）→ アプリ側で取得して URL を得る
        let linkItems = items + [URLQueryItem(name: "skip_http_redirect", value: "true")]
        // ログイン済みのアカウントに別のログイン手段を足すときだけ使う（匿名ログインはしない）
        guard let token = accessToken else { throw OAuthError.message("先にログインしてください") }

        var (status, data) = try await linkAuthorizeFetch(items: linkItems, token: token)
        // 鍵が古ければ1回だけ取り直して再試行
        if status == 401 || status == 403, let rt = refreshToken, (try? await refresh(rt)) != nil, let t2 = accessToken {
            (status, data) = try await linkAuthorizeFetch(items: linkItems, token: t2)
        }
        guard (200..<300).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.contains("manual_linking_disabled") || body.lowercased().contains("manual linking") {
                throw OAuthError.message("サーバーで「手動での連携」がオフです（Supabase → Authentication → Allow manual linking）")
            }
            throw OAuthError.message("連携を始められませんでした(HTTP \(status)): \(body.prefix(140))")
        }
        struct LinkURL: Decodable { let url: String }
        guard let lu = try? JSONDecoder().decode(LinkURL.self, from: data), let u = URL(string: lu.url) else {
            throw OAuthError.message("認可URLの解析に失敗: \(String(data: data, encoding: .utf8)?.prefix(140) ?? "")")
        }
        return u
    }

    private func linkAuthorizeFetch(items: [URLQueryItem], token: String) async throws -> (Int, Data) {
        var comps = URLComponents(string: baseURL + "/auth/v1/user/identities/authorize")!
        comps.queryItems = items
        guard let url = comps.url else { throw OAuthError.message("URL不正") }
        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await dataWithRetry(req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        return (status, data)
    }

    enum OAuthError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
    }

    /// コールバックURLの code を PKCE 交換してセッション確立。
    func oauthExchange(callback: URL) async throws {
        guard let verifier = pendingVerifier else { throw OAuthError.message("内部エラー: verifier 不在") }
        // code は query または fragment(#) のどちらにも来うる
        let comps = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        var items = comps?.queryItems ?? []
        if let frag = comps?.fragment, let fc = URLComponents(string: "?" + frag)?.queryItems { items += fc }
        if let errDesc = items.first(where: { $0.name == "error_description" })?.value
            ?? items.first(where: { $0.name == "error" })?.value {
            if errDesc.lowercased().contains("already") && errDesc.lowercased().contains("linked") ||
               errDesc.contains("identity_already_exists") {
                throw OAuthError.message("このログイン方法は、すでに別の StreetMelody アカウントで使われています")
            }
            throw OAuthError.message("プロバイダ側エラー: \(errDesc)")
        }
        // link はセッションを直接(#access_token=...)で返すことがある → その場合は直接確立
        if let at = items.first(where: { $0.name == "access_token" })?.value,
           let rt = items.first(where: { $0.name == "refresh_token" })?.value {
            try await applyTokens(access: at, refresh: rt)
            pendingVerifier = nil
            return
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.message("コールバックに code がありません: \(callback.absoluteString.prefix(80))")
        }
        // 直接 POST して、失敗時はサーバ本文を表示
        guard let url = URL(string: baseURL + "/auth/v1/token?grant_type=pkce") else { throw OAuthError.message("URL不正") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["auth_code": code, "code_verifier": verifier])
        let (data, resp) = try await dataWithRetry(req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OAuthError.message("交換失敗(HTTP \(http.statusCode)): \(body.prefix(160))")
        }
        _ = try apply(data)
        pendingVerifier = nil
    }

    /// Apple の id_token を REST で交換（link=true で昇格）。
    func signInWithAppleIDToken(_ idToken: String, nonce: String, link: Bool) async throws {
        var obj: [String: Any] = ["provider": "apple", "id_token": idToken, "nonce": nonce]
        if link { obj["link_identity"] = true }
        let body = try JSONSerialization.data(withJSONObject: obj)
        var bearer: String? = nil
        if link { bearer = accessToken }
        let data = try await authRequest(method: "POST", path: "/auth/v1/token?grant_type=id_token", body: body, bearer: bearer)
        _ = try apply(data)
    }

    /// access/refresh トークンから直接セッション確立（/auth/v1/user でユーザー取得）。
    private func applyTokens(access: String, refresh: String) async throws {
        accessToken = access
        refreshToken = refresh
        guard let url = URL(string: baseURL + "/auth/v1/user") else { throw OAuthError.message("URL不正") }
        var req = URLRequest(url: url)
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await dataWithRetry(req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw OAuthError.message("ユーザー取得失敗(HTTP \(http.statusCode)): \(String(data: data, encoding: .utf8)?.prefix(140) ?? "")")
        }
        guard let u = try? JSONDecoder().decode(AuthUser.self, from: data) else {
            throw OAuthError.message("ユーザー解析に失敗: \(String(data: data, encoding: .utf8)?.prefix(140) ?? "")")
        }
        userId = u.id
        email = (u.email?.isEmpty == false) ? u.email : nil
        isAnonymous = u.is_anonymous ?? false
        save(SavedSession(refreshToken: refresh, userId: u.id))
    }

    private static func pkceVerifier(_ n: Int = 64) -> String {
        let cs = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var s = ""
        for _ in 0..<n { var b: UInt8 = 0; _ = SecRandomCopyBytes(kSecRandomDefault, 1, &b); s.append(cs[Int(b) % cs.count]) }
        return s
    }
    private static func pkceChallenge(_ verifier: String) -> String {
        let h = SHA256.hash(data: Data(verifier.utf8))
        return Data(h).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// 外部（Supabase SDK 等）で確立したセッションを取り込み、データ層を共有する。
    /// Apple など OAuth/OIDC サインイン後に呼ぶ。
    func adoptSession(accessToken: String, refreshToken: String, userId: String, email: String?, isAnonymous: Bool) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        self.email = (email?.isEmpty == false) ? email : nil
        self.isAnonymous = isAnonymous
        save(SavedSession(refreshToken: refreshToken, userId: userId))
    }

    private func refresh(_ token: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": token])
        let data = try await authRequest(method: "POST", path: "/auth/v1/token?grant_type=refresh_token", body: body)
        return try apply(data)
    }

    @discardableResult
    private func apply(_ data: Data) throws -> String {
        let s = try JSONDecoder().decode(AuthSession.self, from: data)
        accessToken = s.access_token
        refreshToken = s.refresh_token
        userId = s.user.id
        email = s.user.email?.isEmpty == true ? nil : s.user.email
        isAnonymous = s.user.is_anonymous ?? false
        save(SavedSession(refreshToken: s.refresh_token, userId: s.user.id))
        return s.user.id
    }

    private func authRequest(method: String, path: String, body: Data, bearer: String? = nil) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        req.httpBody = body
        let (data, resp) = try await dataWithRetry(req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AuthError.http(http.statusCode)
        }
        return data
    }

    // MARK: PostgREST helper（per-user 読み書き）

    /// 認証済みトークンで PostgREST にリクエスト。未サインイン時は nil。
    /// schema は既定で streetmelody。共通の名前・ID（public.profiles と public の関数）は "public"。
    /// ログインの鍵（1時間で切れる）が切れていたら、1回だけ取り直してやり直す。
    func rest(method: String, query: String, body: Data? = nil, prefer: String? = nil,
              schema: String = SupabaseClient.appSchema) async throws -> Data? {
        guard accessToken != nil else { return nil }
        guard let url = URL(string: baseURL + "/rest/v1/" + query) else { throw APIError.invalidURL }
        func send() async throws -> (Data, HTTPURLResponse?) {
            var req = URLRequest(url: url)
            req.httpMethod = method
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(anonKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
            // どのスキーマを読むか・書くか（PostgREST は読みと書きで見出しが違う）
            req.setValue(schema, forHTTPHeaderField: "Accept-Profile")
            req.setValue(schema, forHTTPHeaderField: "Content-Profile")
            if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
            req.httpBody = body
            let (data, resp) = try await dataWithRetry(req)
            return (data, resp as? HTTPURLResponse)
        }
        var (data, http) = try await send()
        if http?.statusCode == 401, let rt = refreshToken, (try? await refresh(rt)) != nil {
            (data, http) = try await send()
        }
        if let http, !(200..<300).contains(http.statusCode) {
            throw APIError.httpError(http.statusCode)
        }
        return data
    }

    // MARK: 中継（workers/、streetmelody-relay）

    /// 自前の中継へ、本人のトークンで POST する。未サインイン時は投げる。
    ///
    /// 中継はこのトークンを Supabase に確かめさせて、user_id をそこから取る
    /// （本文の user_id は信用しない。life-os-api/docs/contract.md §3）。
    /// ログインの鍵（1時間で切れる）が切れていたら、1回だけ取り直してやり直す（rest() と同じ）
    func relayPOST(_ url: URL, body: Data) async throws -> (Data, Int) {
        guard accessToken != nil else { throw APIError.httpError(401) }
        func send() async throws -> (Data, Int) {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
            req.httpBody = body
            let (data, resp) = try await dataWithRetry(req)
            return (data, (resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        var (data, status) = try await send()
        if status == 401, let rt = refreshToken, (try? await refresh(rt)) != nil {
            (data, status) = try await send()
        }
        return (data, status)
    }

    // MARK: per-user 状態（方式A）

    struct RemoteFriend: Sendable { let name: String; let location: String; let exchangeCount: Int }
    struct UserState: Sendable {
        var pieces: [String: [Int]] = [:]
        var unlocked: Set<String> = []
        var hints: [String: (level: Int, answerReady: Bool)] = [:]
        var coins: Int? = nil
        var friends: [RemoteFriend] = []
    }
    private struct PieceRow: Decodable { let track_id: String; let piece_number: Int }
    private struct TrackIdRow: Decodable { let track_id: String }
    private struct HintRow: Decodable { let track_id: String; let level: Int; let answer_ready: Bool }
    private struct CoinRow: Decodable { let coins: Int }
    private struct FriendRow: Decodable { let friend_name: String; let location_label: String?; let exchange_count: Int }

    /// 自分の進行・状態をまとめて取得。未サインイン時は空。
    func fetchUserState() async -> UserState {
        var s = UserState()
        if let d = (try? await rest(method: "GET", query: "collected_pieces?select=track_id,piece_number")) ?? nil,
           let rows = try? JSONDecoder().decode([PieceRow].self, from: d) {
            for r in rows { s.pieces[r.track_id, default: []].append(r.piece_number) }
        }
        if let d = (try? await rest(method: "GET", query: "unlocked_tracks?select=track_id")) ?? nil,
           let rows = try? JSONDecoder().decode([TrackIdRow].self, from: d) {
            for r in rows { s.unlocked.insert(r.track_id) }
        }
        if let d = (try? await rest(method: "GET", query: "hint_levels?select=track_id,level,answer_ready")) ?? nil,
           let rows = try? JSONDecoder().decode([HintRow].self, from: d) {
            for r in rows { s.hints[r.track_id] = (r.level, r.answer_ready) }
        }
        if let d = (try? await rest(method: "GET", query: "profiles?select=coins")) ?? nil,
           let rows = try? JSONDecoder().decode([CoinRow].self, from: d), let c = rows.first?.coins {
            s.coins = c
        }
        if let d = (try? await rest(method: "GET", query: "exchange_history?select=friend_name,location_label,exchange_count")) ?? nil,
           let rows = try? JSONDecoder().decode([FriendRow].self, from: d) {
            s.friends = rows.map { RemoteFriend(name: $0.friend_name, location: $0.location_label ?? "", exchangeCount: $0.exchange_count) }
        }
        return s
    }

    func upsertPiece(trackId: String, piece: Int) async {
        guard let uid = userId else { return }
        let body = try? JSONSerialization.data(withJSONObject: [["user_id": uid, "track_id": trackId, "piece_number": piece]])
        _ = try? await rest(method: "POST", query: "collected_pieces?on_conflict=user_id,track_id,piece_number",
                            body: body, prefer: "resolution=ignore-duplicates,return=minimal")
    }

    func upsertUnlock(trackId: String) async {
        guard let uid = userId else { return }
        let body = try? JSONSerialization.data(withJSONObject: [["user_id": uid, "track_id": trackId]])
        _ = try? await rest(method: "POST", query: "unlocked_tracks?on_conflict=user_id,track_id",
                            body: body, prefer: "resolution=ignore-duplicates,return=minimal")
    }

    func upsertHint(trackId: String, level: Int, answerReady: Bool) async {
        guard let uid = userId else { return }
        let row: [String: Any] = ["user_id": uid, "track_id": trackId, "level": level, "answer_ready": answerReady]
        let body = try? JSONSerialization.data(withJSONObject: [row])
        _ = try? await rest(method: "POST", query: "hint_levels?on_conflict=user_id,track_id",
                            body: body, prefer: "resolution=merge-duplicates,return=minimal")
    }

    /// 自分の profiles.coins を更新（profiles 行は signup トリガーで自動生成済み）。
    func updateCoins(_ coins: Int) async {
        guard let uid = userId else { return }
        let body = try? JSONSerialization.data(withJSONObject: [["user_id": uid, "coins": coins]])
        _ = try? await rest(method: "POST", query: "profiles?on_conflict=user_id",
                            body: body, prefer: "resolution=merge-duplicates,return=minimal")
    }

    func upsertFriend(name: String, location: String, exchangeCount: Int) async {
        guard let uid = userId else { return }
        let row: [String: Any] = ["user_id": uid, "friend_name": name, "location_label": location, "exchange_count": exchangeCount]
        let body = try? JSONSerialization.data(withJSONObject: [row])
        _ = try? await rest(method: "POST", query: "exchange_history?on_conflict=user_id,friend_name",
                            body: body, prefer: "resolution=merge-duplicates,return=minimal")
    }

    // MARK: Now Playing（今聴いている曲・共有）

    private struct NowPlayingRow: Decodable {
        let user_id: String
        let display_name: String?
        let service: String
        let track_title: String
        let artist: String?
        let artwork_url: String?
        let started_at: String?
        let updated_at: String?
        let visibility: String
    }

    /// PostgREST の timestamptz 文字列を Date へ（小数秒あり/なしの両方を許容）。
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let isoPlain = ISO8601DateFormatter()
    private static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return isoFractional.date(from: s) ?? isoPlain.date(from: s)
    }
    private func map(_ r: NowPlayingRow) -> NowPlaying {
        NowPlaying(userId: r.user_id, displayName: r.display_name, service: r.service,
                   trackTitle: r.track_title, artist: r.artist, artworkUrl: r.artwork_url,
                   startedAt: Self.parseDate(r.started_at),
                   updatedAt: Self.parseDate(r.updated_at) ?? Date(),
                   visibility: r.visibility)
    }

    /// 自分の「今聴いている曲」を upsert（行は user_id 主キーで最新1件）。
    func upsertNowPlaying(service: String, title: String, artist: String?, artworkUrl: String?,
                          startedAt: Date?, visibility: String, displayName: String?) async {
        guard let uid = userId else { return }
        var row: [String: Any] = [
            "user_id": uid, "service": service, "track_title": title,
            "visibility": visibility, "updated_at": Self.isoFractional.string(from: Date()),
        ]
        if let artist { row["artist"] = artist }
        if let artworkUrl { row["artwork_url"] = artworkUrl }
        if let displayName { row["display_name"] = displayName }
        if let startedAt { row["started_at"] = Self.isoFractional.string(from: startedAt) }
        let body = try? JSONSerialization.data(withJSONObject: [row])
        _ = try? await rest(method: "POST", query: "now_playing?on_conflict=user_id",
                            body: body, prefer: "resolution=merge-duplicates,return=minimal")
    }

    /// 自分の now-playing 行を削除（再生停止・共有OFFで消したいとき）。
    func clearNowPlaying() async {
        guard let uid = userId else { return }
        _ = try? await rest(method: "DELETE", query: "now_playing?user_id=eq.\(uid)", prefer: "return=minimal")
    }

    /// 自分が閲覧できる他ユーザーの now-playing を新着順で取得。
    /// RLS により public 行＋自分がフレンド登録した相手の friends 行が返る（自分は除外）。
    func fetchSharedNowPlaying(limit: Int = 50) async -> [NowPlaying] {
        let cols = "user_id,display_name,service,track_title,artist,artwork_url,started_at,updated_at,visibility"
        var q = "now_playing?select=\(cols)&order=updated_at.desc&limit=\(limit)"
        if let uid = userId { q += "&user_id=neq.\(uid)" }
        guard let d = (try? await rest(method: "GET", query: q)) ?? nil,
              let rows = try? JSONDecoder().decode([NowPlayingRow].self, from: d) else { return [] }
        return rows.map(map)
    }

    /// フレンドコード（相手の user_id）でフレンド追加。以後その相手の friends 共有を閲覧できる。
    func addFriendByCode(friendUserId: String, nickname: String) async throws {
        guard let uid = userId else { throw AuthError.notSignedIn }
        let code = friendUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard code.count == 36, code != uid.lowercased() else {
            throw OAuthError.message(code == uid.lowercased() ? "自分のコードは追加できません" : "コードの形式が正しくありません")
        }
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let row: [String: Any] = [
            "user_id": uid, "friend_user_id": code, "exchange_count": 1,
            "friend_name": name.isEmpty ? "フレンド(\(code.suffix(4)))" : name,
        ]
        let body = try JSONSerialization.data(withJSONObject: [row])
        _ = try await rest(method: "POST", query: "exchange_history?on_conflict=user_id,friend_name",
                           body: body, prefer: "resolution=merge-duplicates,return=minimal")
    }

    /// 自分の user_id（すれちがいの BLE で名乗る・マイメロディの種）。
    func myFriendCode() -> String? { userId }

    // MARK: プロフィール
    //
    // 名前・ユーザーID・ひとことは共通アカウントの public.profiles（StyleCare などと同じもの）。
    // ここを変えると、他のアプリでも同じ名前・IDになる。
    // 好きなアーティスト・曲、誕生日などは StreetMelody だけのもの（streetmelody.profiles）。

    struct UserProfile: Codable, Sendable, Equatable {
        var handle: String?
        var displayName: String?
        var bio: String?
        var favoriteArtistIds: [String] = []
        var favoriteTrackIds: [String] = []
        var birthday: String?      // "yyyy-MM-dd"
        var gender: String?        // "male"|"female"|"other"|"na"
        var visibility: [String: String] = [:]   // 項目→スコープ
    }
    private struct CommonProfileRow: Decodable {
        let handle: String?; let display_name: String?; let bio: String?
    }
    private struct AppProfileRow: Decodable {
        let favorite_artist_ids: [String]?; let favorite_track_ids: [String]?
        let birthday: String?; let gender: String?; let profile_visibility: [String: String]?
    }
    private struct HandleResult: Decodable { let ok: Bool; let error: String? }

    /// 自分のプロフィールを取得（共通の名前・ID ＋ StreetMelody 固有の項目）。
    func fetchMyProfile() async -> UserProfile? {
        guard let uid = userId else { return nil }
        guard let d = (try? await rest(method: "GET", query: "profiles?id=eq.\(uid)&select=handle,display_name,bio",
                                       schema: "public")) ?? nil,
              let common = (try? JSONDecoder().decode([CommonProfileRow].self, from: d))?.first else { return nil }
        var p = UserProfile(handle: common.handle, displayName: common.display_name, bio: common.bio)
        let cols = "favorite_artist_ids,favorite_track_ids,birthday,gender,profile_visibility"
        if let ad = (try? await rest(method: "GET", query: "profiles?user_id=eq.\(uid)&select=\(cols)")) ?? nil,
           let app = (try? JSONDecoder().decode([AppProfileRow].self, from: ad))?.first {
            p.favoriteArtistIds = app.favorite_artist_ids ?? []
            p.favoriteTrackIds = app.favorite_track_ids ?? []
            p.birthday = app.birthday
            p.gender = app.gender
            p.visibility = app.profile_visibility ?? [:]
        }
        return p
    }

    /// 自分のプロフィールを更新。ID は public.change_handle（変更の間隔・重複・最近手放されたIDを見る）。
    func updateMyProfile(_ p: UserProfile) async throws {
        guard let uid = userId else { throw AuthError.notSignedIn }

        // ① ユーザーID（変わったときだけ）
        let current = await fetchMyProfile()?.handle
        if let h = p.handle?.trimmingCharacters(in: .whitespaces), !h.isEmpty,
           h.lowercased() != (current ?? "").lowercased() {
            let body = try JSONSerialization.data(withJSONObject: ["new_handle": h])
            guard let d = try await rest(method: "POST", query: "rpc/change_handle", body: body, schema: "public"),
                  let r = try? JSONDecoder().decode(HandleResult.self, from: d) else {
                throw OAuthError.message("ユーザーIDを変更できませんでした")
            }
            if !r.ok { throw OAuthError.message(r.error ?? "ユーザーIDを変更できませんでした") }
        }

        // ② 名前・ひとこと（共通）
        let common: [String: Any] = ["display_name": p.displayName ?? NSNull(), "bio": p.bio ?? NSNull()]
        _ = try await rest(method: "PATCH", query: "profiles?id=eq.\(uid)",
                           body: try JSONSerialization.data(withJSONObject: common),
                           prefer: "return=minimal", schema: "public")

        // ③ StreetMelody だけの項目（行が無ければ作る）
        let app: [String: Any] = [
            "user_id": uid,
            "favorite_artist_ids": p.favoriteArtistIds,
            "favorite_track_ids": p.favoriteTrackIds,
            "profile_visibility": p.visibility,
            "birthday": p.birthday ?? NSNull(),
            "gender": p.gender ?? NSNull(),
        ]
        _ = try await rest(method: "POST", query: "profiles?on_conflict=user_id",
                           body: try JSONSerialization.data(withJSONObject: [app]),
                           prefer: "resolution=merge-duplicates,return=minimal")
    }

    /// ユーザーIDの空き確認（共通の public.is_handle_available）。
    func checkHandleAvailable(_ handle: String) async -> Bool {
        let body = try? JSONSerialization.data(withJSONObject: ["h": handle])
        guard let d = (try? await rest(method: "POST", query: "rpc/is_handle_available", body: body, schema: "public")) ?? nil,
              let ok = try? JSONDecoder().decode(Bool.self, from: d) else { return false }
        return ok
    }

    // MARK: フレンド（申請 → 相手が承認。StyleCare の仲間と同じ）
    //
    // friend_links（requester / addressee / status）。承認は受けた側だけができ、
    // 取り消し・断る・解除はどちらからでもできる（RLS で守る）。
    // 2人が同時に申請し合ったら、サーバー側で待たずにフレンドになる。

    struct PublicProfile: Sendable, Equatable {
        let userId: String
        let handle: String?
        let displayName: String?
        var avatarURL: String? = nil
        var name: String { displayName ?? handle.map { "@\($0)" } ?? "ユーザー(\(userId.suffix(4)))" }
    }

    struct FriendUser: Sendable, Identifiable, Equatable {
        enum State: Sendable { case friend, incoming, outgoing }
        let userId: String
        var handle: String?
        var displayName: String?
        var state: State
        var isBest: Bool
        var since: Date?
        var id: String { userId }
        var name: String { displayName ?? handle.map { "@\($0)" } ?? "ユーザー(\(userId.suffix(4)))" }
    }

    private struct LinkRow: Decodable { let requester: String; let addressee: String; let status: String; let accepted_at: String? }
    private struct BestRow: Decodable { let friend_id: String }
    private struct NameRow: Decodable { let id: String; let handle: String?; let display_name: String?; let avatar_url: String? }

    /// 自分が関わる申請・フレンドを、相手ごとにまとめて返す。
    func fetchFriends() async -> [FriendUser] {
        guard let uid = userId?.lowercased() else { return [] }
        let q = "friend_links?select=requester,addressee,status,accepted_at&or=(requester.eq.\(uid),addressee.eq.\(uid))"
        guard let d = (try? await rest(method: "GET", query: q)) ?? nil,
              let rows = try? JSONDecoder().decode([LinkRow].self, from: d) else { return [] }
        var bests = Set<String>()
        if let bd = (try? await rest(method: "GET", query: "friend_bests?select=friend_id&user_id=eq.\(uid)")) ?? nil,
           let br = try? JSONDecoder().decode([BestRow].self, from: bd) {
            bests = Set(br.map { $0.friend_id.lowercased() })
        }
        let others = rows.map { $0.requester.lowercased() == uid ? $0.addressee : $0.requester }
        let names = await displayNames(for: others)
        return rows.map { r in
            let other = r.requester.lowercased() == uid ? r.addressee : r.requester
            let state: FriendUser.State = r.status == "accepted" ? .friend
                : (r.requester.lowercased() == uid ? .outgoing : .incoming)
            let p = names[other.lowercased()]
            return FriendUser(userId: other, handle: p?.handle, displayName: p?.displayName, state: state,
                              isBest: bests.contains(other.lowercased()),
                              since: Self.parseDate(r.accepted_at))
        }
        .sorted { $0.name < $1.name }
    }

    /// 表示名とIDをまとめて引く（関係を問わず見せてよいのはこの2つだけ）。
    func displayNames(for ids: [String]) async -> [String: PublicProfile] {
        let uniq = Array(Set(ids.map { $0.lowercased() }))
        guard !uniq.isEmpty, let body = try? JSONSerialization.data(withJSONObject: ["ids": uniq]),
              let d = (try? await rest(method: "POST", query: "rpc/get_display_names", body: body, schema: "public")) ?? nil,
              let rows = try? JSONDecoder().decode([NameRow].self, from: d) else { return [:] }
        var out: [String: PublicProfile] = [:]
        for r in rows {
            out[r.id.lowercased()] = PublicProfile(userId: r.id, handle: r.handle, displayName: r.display_name, avatarURL: r.avatar_url)
        }
        return out
    }

    /// ユーザーID（handle）で人を探す。
    func findUser(handle: String) async -> PublicProfile? {
        let h = handle.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        struct FoundRow: Decodable { let id: String; let handle: String?; let display_name: String? }
        guard !h.isEmpty, let body = try? JSONSerialization.data(withJSONObject: ["h": h]),
              let d = (try? await rest(method: "POST", query: "rpc/find_user_by_handle", body: body, schema: "public")) ?? nil,
              let r = (try? JSONDecoder().decode([FoundRow].self, from: d))?.first else { return nil }
        return PublicProfile(userId: r.id, handle: r.handle, displayName: r.display_name)
    }

    /// 申請を送る。相手からも申請が来ていれば、その場でフレンドになる（サーバー側）。
    func sendFriendRequest(to otherId: String) async throws {
        guard let uid = userId else { throw AuthError.notSignedIn }
        guard otherId.lowercased() != uid.lowercased() else { throw OAuthError.message("自分には申請できません") }
        let body = try JSONSerialization.data(withJSONObject: [["requester": uid, "addressee": otherId]])
        do {
            _ = try await rest(method: "POST", query: "friend_links", body: body, prefer: "return=minimal")
        } catch APIError.httpError(let code) where code == 409 {
            throw OAuthError.message("この人とはすでに申請中かフレンドです")
        }
    }

    /// 届いた申請を承認する。
    func acceptFriendRequest(from otherId: String) async throws {
        guard let uid = userId else { throw AuthError.notSignedIn }
        let body = try JSONSerialization.data(withJSONObject: ["status": "accepted"])
        _ = try await rest(method: "PATCH", query: "friend_links?requester=eq.\(otherId)&addressee=eq.\(uid)&status=eq.pending",
                           body: body, prefer: "return=minimal")
    }

    /// 申請の取り消し・断る・フレンド解除（どれも行を消す）。
    func removeFriendLink(with otherId: String) async throws {
        guard let uid = userId else { throw AuthError.notSignedIn }
        let q = "friend_links?or=(and(requester.eq.\(uid),addressee.eq.\(otherId)),and(requester.eq.\(otherId),addressee.eq.\(uid)))"
        _ = try await rest(method: "DELETE", query: q, prefer: "return=minimal")
    }

    /// ベスト指定の ON/OFF（自分→相手）。フレンドの相手にだけ付けられる（RLS）。
    func setBestFriend(_ otherId: String, isBest: Bool) async throws {
        guard let uid = userId else { throw AuthError.notSignedIn }
        if isBest {
            let body = try JSONSerialization.data(withJSONObject: [["user_id": uid, "friend_id": otherId]])
            _ = try await rest(method: "POST", query: "friend_bests?on_conflict=user_id,friend_id", body: body,
                               prefer: "resolution=ignore-duplicates,return=minimal")
        } else {
            _ = try await rest(method: "DELETE", query: "friend_bests?user_id=eq.\(uid)&friend_id=eq.\(otherId)",
                               prefer: "return=minimal")
        }
    }

    // MARK: Persistence

    private func save(_ s: SavedSession) {
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: sessionKey) }
    }
    private func loadSaved() -> SavedSession? {
        guard let d = UserDefaults.standard.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(SavedSession.self, from: d)
    }
}
