import Foundation
import Combine
import MediaPlayer

// MARK: - MusicTrack / ActivePlayback

struct MusicTrack: Sendable, Equatable {
    var title: String
    var artist: String?
    var artworkUrl: String?
    var startedAt: Date?
    var isPlaying: Bool
}

/// 今まさに再生中の1曲（再生中のみ・停止/一時停止中は nil）。
struct ActivePlayback: Equatable, Sendable {
    var track: MusicTrack
    var service: MusicService
}

// MARK: - Keychain（third-party トークンの保管）

private enum Keychain {
    static func set(_ data: Data, for key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
    static func get(_ key: String) -> Data? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
    static func delete(_ key: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key] as CFDictionary)
    }
}

// MARK: - MusicConnectManager
//
// ログイン（Supabase OAuth）とは独立した「音楽サービス連携」。
// 「今まさに再生中の曲」をライブに公開（@Published active）し、再生操作も提供する。
// - Spotify: App Remote で端末の Spotify アプリへ直結し playerState を購読（無料アカウント可）。
// - Apple Music: MediaPlayer の systemMusicPlayer を通知で監視（有料プログラム不要）。
// どちらも「再生中(isPlaying)」のときだけ active に採用する。両方再生中なら Spotify 優先。

@MainActor
final class MusicConnectManager: ObservableObject {
    static let shared = MusicConnectManager()

    /// 今再生中の曲（停止・一時停止中は nil）。UI/共有はこれを見る。
    @Published private(set) var active: ActivePlayback?

    enum MusicError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
    }

    // サービス別の最新「再生中トラック」。再生していなければ nil。
    private var spotifyPlaying: MusicTrack?
    private var applePlaying: MusicTrack?

    private init() {
        appRemote.onToken = { [weak self] token in self?.saveSpotifyToken(token) }
        appRemote.onPlayerState = { [weak self] track in
            self?.spotifyPlaying = track   // 再生/一時停止とも保持（停止・曲なし・切断は nil）
            self?.recompute()
        }
    }

    // MARK: Spotify（App Remote）

    private enum Spotify {
        static let clientID = "bbdf2c9d61d6448387b470ba58cda1f1"
        static let redirect = "com.streetmelody.app://spotify-callback"
        static let tokenKey = "streetmelody.spotify.appremote.token.v1"
    }

    private lazy var appRemote = SpotifyAppRemoteController(
        clientID: Spotify.clientID, redirectURL: URL(string: Spotify.redirect)!)

    private func saveSpotifyToken(_ t: String) { Keychain.set(Data(t.utf8), for: Spotify.tokenKey) }
    private func loadSpotifyToken() -> String? {
        Keychain.get(Spotify.tokenKey).flatMap { String(data: $0, encoding: .utf8) }
    }

    var isSpotifyConnected: Bool { loadSpotifyToken() != nil }

    /// Spotify を連携（Spotifyアプリで認可→接続→購読開始）。app-switch あり。
    func connectSpotify() async throws { try await appRemote.authorizeAndConnect() }

    func disconnectSpotify() {
        appRemote.disconnect()
        Keychain.delete(Spotify.tokenKey)
        spotifyPlaying = nil
        recompute()
    }

    /// 既存トークンでの再接続を試みる（前面復帰時など）。失敗は無視（次回連携で回復）。
    func ensureSpotifyConnected() async {
        guard let token = loadSpotifyToken(), !appRemote.isConnected else { return }
        try? await appRemote.reconnect(accessToken: token)
    }

    /// authorizeAndPlayURI の戻りURL（App の onOpenURL から呼ぶ）。
    func handleSpotifyURL(_ url: URL) { appRemote.handleCallback(url) }

    // MARK: Apple Music（MediaPlayer・端末ローカル・通知監視）

    var isAppleMusicAuthorized: Bool { MPMediaLibrary.authorizationStatus() == .authorized }

    func requestAppleMusicAuth() async -> Bool {
        if MPMediaLibrary.authorizationStatus() == .authorized { startAppleObservation(); return true }
        let ok = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            MPMediaLibrary.requestAuthorization { status in cont.resume(returning: status == .authorized) }
        }
        if ok { startAppleObservation() }
        return ok
    }

    private var appleObserving = false
    private var applePollTask: Task<Void, Never>?
    /// systemMusicPlayer の曲・再生状態の変化を監視（再生中のみ active 採用）。
    /// 通知は初回状態を取りこぼすことがあるため、2秒ポーリングも併用して確実化する。
    func startAppleObservation() {
        guard MPMediaLibrary.authorizationStatus() == .authorized else { return }
        if !appleObserving {
            appleObserving = true
            let player = MPMusicPlayerController.systemMusicPlayer
            player.beginGeneratingPlaybackNotifications()
            let nc = NotificationCenter.default
            nc.addObserver(self, selector: #selector(appleChanged),
                           name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
            nc.addObserver(self, selector: #selector(appleChanged),
                           name: .MPMusicPlayerControllerPlaybackStateDidChange, object: player)
        }
        applePollTask?.cancel()
        applePollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.appleChanged()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }


    // 一度でも .playing を観測したら「能動セッション」とみなす。
    // 起動直後に残っている古い一時停止アイテム（ユーザーが再生していない）を弾くため。
    private var appleWasPlaying = false

    @objc private func appleChanged() {
        let player = MPMusicPlayerController.systemMusicPlayer
        let item = player.nowPlayingItem
        switch player.playbackState {
        case .playing:
            appleWasPlaying = true
            applePlaying = item?.title.map { MusicTrack(title: $0, artist: item?.artist, artworkUrl: nil, startedAt: nil, isPlaying: true) }
        case .paused:
            // 能動セッション中の一時停止のみ表示（古い残りは出さない）
            applePlaying = (appleWasPlaying ? item?.title : nil).map { MusicTrack(title: $0, artist: item?.artist, artworkUrl: nil, startedAt: nil, isPlaying: false) }
        default:
            appleWasPlaying = false
            applePlaying = nil
        }
        recompute()
    }

    // MARK: active 計算 & 再生操作

    private func recompute() {
        // 再生中を最優先（両方再生中なら Spotify）。再生中が無ければ一時停止中を表示。
        if spotifyPlaying?.isPlaying == true { active = ActivePlayback(track: spotifyPlaying!, service: .spotify); return }
        if applePlaying?.isPlaying == true { active = ActivePlayback(track: applePlaying!, service: .appleMusic); return }
        if let s = spotifyPlaying { active = ActivePlayback(track: s, service: .spotify); return }
        if let a = applePlaying { active = ActivePlayback(track: a, service: .appleMusic); return }
        active = nil
    }

    /// 再生/一時停止トグル（active のサービスに対して）。
    func togglePlayPause() {
        guard let svc = active?.service else { return }
        switch svc {
        case .spotify:
            if active?.track.isPlaying == true { appRemote.pause() } else { appRemote.resume() }
        case .appleMusic:
            let p = MPMusicPlayerController.systemMusicPlayer
            p.playbackState == .playing ? p.pause() : p.play()
        default: break
        }
    }
    func next() {
        switch active?.service {
        case .spotify: appRemote.skipToNext()
        case .appleMusic: MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
        default: break
        }
    }
    func previous() {
        switch active?.service {
        case .spotify: appRemote.skipToPrev()
        case .appleMusic: MPMusicPlayerController.systemMusicPlayer.skipToPreviousItem()
        default: break
        }
    }
}
