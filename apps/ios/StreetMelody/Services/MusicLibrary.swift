import Foundation
import MediaPlayer
import UIKit

// MARK: - MusicLibrary
//
// 端末の Apple Music（ミュージックアプリ）ライブラリからアーティスト/曲名を読む。
// MPMediaQuery はローカルライブラリ参照のため無料アカウントで可（NSAppleMusicUsageDescription＋
// メディアライブラリ許可が前提）。お気に入りの選択候補に使う。

enum MusicLibrary {
    static var isAuthorized: Bool { MPMediaLibrary.authorizationStatus() == .authorized }

    /// ライブラリ内アーティスト名（重複排除・名前順）。
    static func artistNames(limit: Int = 500) -> [String] {
        guard isAuthorized else { return [] }
        let q = MPMediaQuery.artists()
        let names = (q.collections ?? []).compactMap { $0.representativeItem?.artist }
        return Array(Set(names)).sorted().prefix(limit).map { $0 }
    }

    /// ライブラリ内の曲（タイトル＋アーティスト・重複排除）。
    static func songs(limit: Int = 1000) -> [(title: String, artist: String)] {
        guard isAuthorized else { return [] }
        let q = MPMediaQuery.songs()
        var seen = Set<String>()
        var out: [(String, String)] = []
        for item in (q.items ?? []) {
            guard let t = item.title, !t.isEmpty else { continue }
            let a = item.artist ?? ""
            if seen.insert(t + "\u{1}" + a).inserted { out.append((t, a)) }
            if out.count >= limit { break }
        }
        return out.sorted { $0.0 < $1.0 }
    }
}

// MARK: - iTunes Search API（無料・公式・Apple Music 全カタログ検索）
//
// MusicKit カタログ検索は有料 Developer Program＋エンタイトルメント必須だが、
// iTunes Search API は認証不要で全曲/全アーティストを検索できる（無料Teamで可）。

enum ITunesSearch {
    struct Result: Identifiable, Sendable, Equatable {
        let id: String          // 表示・選択キー（名前）
        var name: String { id }
        let subtitle: String    // 曲ならアーティスト名
        let artworkUrl: String?
    }

    /// term で検索。isArtist=true はアーティスト、false は曲。
    static func search(term: String, isArtist: Bool) async -> [Result] {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 1 else { return [] }
        var c = URLComponents(string: "https://itunes.apple.com/search")!
        c.queryItems = [
            URLQueryItem(name: "term", value: t),
            URLQueryItem(name: "country", value: "JP"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: isArtist ? "musicArtist" : "song"),
            URLQueryItem(name: "limit", value: "25"),
        ]
        guard let url = c.url, let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
        struct Resp: Decodable { let results: [Item] }
        struct Item: Decodable { let artistName: String?; let trackName: String?; let artworkUrl100: String? }
        guard let r = try? JSONDecoder().decode(Resp.self, from: data) else { return [] }
        var seen = Set<String>()
        var out: [Result] = []
        for it in r.results {
            let name = isArtist ? it.artistName : it.trackName
            guard let n = name, !n.isEmpty, seen.insert(n).inserted else { continue }
            out.append(Result(id: n, subtitle: isArtist ? "" : (it.artistName ?? ""), artworkUrl: it.artworkUrl100))
        }
        return out
    }

    /// 曲の30秒プレビュー音源URL（best match）。AVPlayer で確実に再生できる。
    static func previewURL(title: String, artist: String) async -> URL? {
        var c = URLComponents(string: "https://itunes.apple.com/search")!
        c.queryItems = [
            URLQueryItem(name: "term", value: "\(title) \(artist)"),
            URLQueryItem(name: "country", value: "JP"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "3"),
        ]
        guard let url = c.url, let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        struct R: Decodable { let results: [I] }
        struct I: Decodable { let previewUrl: String? }
        let r = try? JSONDecoder().decode(R.self, from: data)
        return r?.results.compactMap { $0.previewUrl }.first.flatMap { URL(string: $0) }
    }

    /// 曲の Apple Music ページURL（best match）。外部アプリで開く用。
    static func trackURL(title: String, artist: String) async -> URL? {
        var c = URLComponents(string: "https://itunes.apple.com/search")!
        c.queryItems = [
            URLQueryItem(name: "term", value: "\(title) \(artist)"),
            URLQueryItem(name: "country", value: "JP"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        guard let url = c.url, let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        struct R: Decodable { let results: [I] }
        struct I: Decodable { let trackViewUrl: String? }
        return (try? JSONDecoder().decode(R.self, from: data))?.results.first?.trackViewUrl.flatMap { URL(string: $0) }
    }
}

// MARK: - 外部音楽アプリで開く（無料アカウントでのバックグラウンド再生手段）

enum ExternalMusic {
    /// Apple Music アプリでその曲を開く（見つからなければ検索を開く）。
    @MainActor static func openAppleMusic(title: String, artist: String) {
        Task { @MainActor in
            if let url = await ITunesSearch.trackURL(title: title, artist: artist) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                let q = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
                if let u = URL(string: "https://music.apple.com/jp/search?term=\(q)") {
                    UIApplication.shared.open(u, options: [:], completionHandler: nil)
                }
            }
        }
    }

    /// Spotify アプリでその曲を検索して開く。
    @MainActor static func openSpotify(title: String, artist: String) {
        let q = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        if let u = URL(string: "https://open.spotify.com/search/\(q)") {
            UIApplication.shared.open(u, options: [:], completionHandler: nil)
        }
    }
}
