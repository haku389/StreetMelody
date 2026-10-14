import Foundation
import SpotifyiOS

// MARK: - SpotifyAppRemoteController
//
// Spotify iOS SDK（App Remote）で端末の Spotify アプリへ直接つなぎ、再生状態を購読する。
// Web API の me/player/* はオーナー Premium 必須だが、App Remote は無料アカウントでも可。
//
// 接続フロー: authorizeAndPlayURI("")（app-switch・認可）→ onOpenURL → handleCallback →
//             connect() → appRemoteDidEstablishConnection → playerAPI を購読。
// 以後 playerStateDidChange でライブに曲・再生状態が届く。

@MainActor
final class SpotifyAppRemoteController: NSObject, @preconcurrency SPTAppRemoteDelegate, @preconcurrency SPTAppRemotePlayerStateDelegate {

    enum RemoteError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
    }

    private let appRemote: SPTAppRemote
    private var connectCont: CheckedContinuation<Void, Error>?
    private var gen = 0

    /// 認可コールバックで得たアクセストークンを上位へ通知（保存用）。
    var onToken: ((String) -> Void)?
    /// 再生状態が変わるたびに最新トラックを通知（再生していない/曲なしは nil）。
    var onPlayerState: ((MusicTrack?) -> Void)?

    init(clientID: String, redirectURL: URL) {
        let cfg = SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
        appRemote = SPTAppRemote(configuration: cfg, logLevel: .none)
        super.init()
        appRemote.delegate = self
    }

    var isConnected: Bool { appRemote.isConnected }

    /// Spotifyアプリを起動して認可→接続（初回・再認可）。app-switch あり。
    func authorizeAndConnect() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            beginWait(cont, timeout: 90, timeoutMessage: "Spotify連携がタイムアウトしました。もう一度お試しください。")
            appRemote.authorizeAndPlayURI("") { [weak self] success in
                if !success {
                    self?.finish(.failure(RemoteError.message("Spotifyアプリが見つかりません。App Store から Spotify を入れてください。")))
                }
            }
        }
    }

    /// 既存トークンで接続（セッションが生きていれば app-switch 不要）。
    func reconnect(accessToken: String) async throws {
        appRemote.connectionParameters.accessToken = accessToken
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            beginWait(cont, timeout: 5, timeoutMessage: "Spotifyに再接続できませんでした。")
            appRemote.connect()
        }
    }

    /// authorizeAndPlayURI の戻りURLを処理（onOpenURL から呼ぶ）。
    func handleCallback(_ url: URL) {
        guard let params = appRemote.authorizationParameters(from: url) else { return }
        if let token = params[SPTAppRemoteAccessTokenKey] {
            onToken?(token)
            appRemote.connectionParameters.accessToken = token
            appRemote.connect()
        } else if let err = params[SPTAppRemoteErrorDescriptionKey] {
            finish(.failure(RemoteError.message("Spotify認可エラー: \(err)")))
        }
    }

    func disconnect() {
        onPlayerState?(nil)
        if appRemote.isConnected { appRemote.disconnect() }
    }

    // MARK: 再生操作（active が Spotify のときに使う）

    func resume()       { appRemote.playerAPI?.resume(nil) }
    func pause()        { appRemote.playerAPI?.pause(nil) }
    func skipToNext()   { appRemote.playerAPI?.skip(toNext: nil) }
    func skipToPrev()   { appRemote.playerAPI?.skip(toPrevious: nil) }

    // MARK: - 接続待ち管理

    private func beginWait(_ cont: CheckedContinuation<Void, Error>, timeout: UInt64, timeoutMessage: String) {
        connectCont = cont
        gen += 1
        let myGen = gen
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: timeout * 1_000_000_000)
            guard let self, self.gen == myGen else { return }
            self.finish(.failure(RemoteError.message(timeoutMessage)))
        }
    }
    private func finish(_ result: Result<Void, Error>) {
        guard let c = connectCont else { return }
        connectCont = nil
        gen += 1
        switch result {
        case .success: c.resume()
        case .failure(let e): c.resume(throwing: e)
        }
    }

    private func emit(_ state: SPTAppRemotePlayerState) {
        let t = state.track
        guard !t.name.isEmpty else { onPlayerState?(nil); return }
        let artist = t.artist.name
        onPlayerState?(MusicTrack(title: t.name, artist: artist.isEmpty ? nil : artist,
                                  artworkUrl: nil, startedAt: nil, isPlaying: !state.isPaused))
    }

    // MARK: - SPTAppRemoteDelegate

    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        finish(.success(()))
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: nil)
        appRemote.playerAPI?.getPlayerState { [weak self] result, _ in
            if let s = result as? SPTAppRemotePlayerState { self?.emit(s) }
        }
    }
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        let d: String
        if let e = error as NSError? { d = "App Remote接続失敗 [\(e.domain)#\(e.code)] \(e.localizedDescription)" }
        else { d = "Spotifyアプリへの接続に失敗しました。" }
        finish(.failure(RemoteError.message(d)))
    }
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        onPlayerState?(nil)
    }

    // MARK: - SPTAppRemotePlayerStateDelegate

    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        emit(playerState)
    }
}
