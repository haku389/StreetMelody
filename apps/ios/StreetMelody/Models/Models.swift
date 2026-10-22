import Foundation

// MARK: - User

struct User: Codable, Identifiable {
    let id: String
    var name: String
    var level: Int
    var exp: Int
    var coins: Int
}

// MARK: - Artist

struct Artist: Codable, Identifiable {
    let id: String
    let name: String
}

// MARK: - Track

struct Track: Codable, Identifiable {
    let id: String
    let artistId: String
    let pieceCount: Int
    let rewardCoins: Int
    let rewardExp: Int
    let color: String
    let tone: String?

    var title: String?
    var artistName: String?
    var isUnlocked: Bool
    var hintLevel: Int
    var answerReady: Bool
    var maskedLabel: String?
    var choices: [String]
    var ownedPieces: [Int]
    var youtubeVideoId: String?
    var chorusStart: Int? = nil   // サビ位置（秒）。30秒試聴の開始位置
    var thumbnailUrl: String? = nil   // 旧API由来サムネ。著作権方針により公開表示では使用しない（独自生成カードに移行）
    var genre: String? = nil      // ジャンル（Lv1ヒント）。未設定なら id から決定的に導出
    var era: String? = nil        // 年代（Lv1ヒント）
    var mood: String? = nil       // 雰囲気（Lv1ヒント）

    // 曲名は「曲名を答えて解放（isUnlocked）」するまでマスク。Lv2で一部の文字が開く。
    // アーティスト名は初期状態でも常に表示する。
    var displayTitle: String { isUnlocked ? (title ?? "メロディ") : maskedTitle(hintLevel: hintLevel) }
    var displayArtist: String { artistName ?? "—" }
    var isComplete: Bool { ownedPieces.count >= pieceCount }

    // MARK: 独自カード/段階ヒント用（公式画像を使わずアプリ側で決定的に生成）

    static func mlHash(_ s: String) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h
    }
    private static func pick(_ s: String, _ a: [String]) -> String { a[Int(mlHash(s) % UInt64(a.count))] }

    var genreHint: String { genre ?? Track.pick(id + "g", ["J-POP","ロック","ヒップホップ","R&B/ソウル","ダンス/EDM","バラード","アニソン/ボカロ","シティポップ"]) }
    var eraHint:   String { era   ?? Track.pick(id + "e", ["1990年代","2000年代","2010年代","2020年代"]) }
    var moodHint:  String { mood  ?? Track.pick(id + "m", ["切ない","夜っぽい","疾走感","エモい","爽やか","アガる","しっとり","ノスタルジック"]) }

    /// 曲名のマスク表示。Lv2(hintLevel>=2)で約4割の文字が開く（決定的）。
    func maskedTitle(hintLevel: Int) -> String {
        if isUnlocked { return title ?? "メロディ" }
        guard let t = title, !t.isEmpty else { return "？？？？？？" }
        let reveal: Double = hintLevel >= 2 ? 0.4 : 0
        var h = Track.mlHash(id + "title")
        var out = ""
        for ch in t {
            if ch == " " || ch == "　" { out.append(ch); continue }
            h = h &* 6364136223846793005 &+ 1442695040888963407
            let r = Double((h >> 33) % 1000) / 1000.0
            out.append(r < reveal ? ch : "？")
        }
        return out
    }

    /// 実在する YouTube 動画を持つか（30秒試聴・YouTube確認の可否判定に使う）。
    /// 架空曲（`youtubeVideoId == nil` または `official-*`）は false。
    var hasYouTubeVideo: Bool {
        guard let id = youtubeVideoId, !id.hasPrefix("official-") else { return false }
        return true
    }

    /// アプリに同梱したパズルプレビュー画像（Web版 assets/puzzles/<id>/preview.png 由来）。
    /// XcodeGen がバンドル直下にフラット化するため subdirectory なしで検索する。
    var bundledThumbnailURL: URL? {
        Bundle.main.url(forResource: id, withExtension: "png")
    }

    /// 表示用サムネイル URL。優先順位は次のとおり:
    ///  1) API(DB/CDN)由来の thumbnailUrl（公式MVの maxres など。将来の配信元）
    ///  2) YouTube 画像CDN の maxresdefault（1280×720 の 16:9。無い動画は CachedThumbnail が hqdefault に落とす）
    ///  3) アプリ同梱画像（YouTube の動画が無い曲だけ）
    /// 同梱画像は Web 版のパズル見本で、6×4 の線と黒帯が焼き込まれ横に伸びているため、16:9 の枠では使わない。
    var thumbnailURL: URL? {
        if let remote = thumbnailUrl, let u = URL(string: remote) { return u }
        if let id = youtubeVideoId, !id.hasPrefix("official-") {
            return URL(string: "https://i.ytimg.com/vi/\(id)/maxresdefault.jpg")
        }
        return bundledThumbnailURL
    }
}

// MARK: - Encounter

struct Encounter: Codable, Identifiable {
    let id: String
    let locationLabel: String
    let fromUserName: String
    let fromUserId: String
    let rewardCoins: Int
    let expiresAt: Date
    let candidates: [Candidate]
}

struct Candidate: Codable, Identifiable {
    let id: String
    let trackId: String
    let pieceNumber: Int
    let sourceSlot: String
    let rarity: Int
    let sortOrder: Int
    var availablePieces: [Int]
}

// MARK: - Playlist

struct DailyPlaylist: Codable, Identifiable {
    let id: String
    let date: String
    let title: String
    let tracks: [PlaylistItem]
}

struct PlaylistItem: Codable {
    let trackId: String
    let artistId: String
    let color: String
}

// MARK: - Mission

struct Mission: Codable {
    let userId: String
    let date: String
    let label: String
    var current: Int
    let target: Int
    let rewardCoins: Int

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(current) / Double(target))   // 超過しても 1.0 で止める
    }
    /// 表示用の達成数（target を超えない）。
    var displayCurrent: Int { min(current, target) }
    var claimed: Bool { current >= target }
}

// MARK: - Collection Summary

struct CollectionSummary: Codable {
    let completedPuzzles: Int
    let totalPuzzles: Int
    let completedArtists: Int
    let totalArtists: Int
    let playlists: Int
}

// MARK: - Friend

struct Friend: Identifiable, Codable {
    let userId: String
    var id: String { userId }
    let userName: String
    let locationLabel: String
    var exchangeCount: Int
    let addedAt: Date
}

// MARK: - Now Playing（今聴いている曲・共有）

/// 音楽サービス種別。rawValue は now_playing.service 列・linkedServices のキーと一致させる。
enum MusicService: String, Codable, CaseIterable, Sendable {
    case spotify
    case appleMusic = "appleMusic"
    case youtubeMusic = "youtubeMusic"
    case manual

    var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        case .youtubeMusic: return "YouTube Music"
        case .manual: return "手動"
        }
    }
    /// now-playing を自動取得できるか（YouTube Music は公式APIが無く手動のみ）。
    var supportsNowPlaying: Bool { self == .spotify || self == .appleMusic }
}

/// 「今聴いている曲」。自分の最新1件 or フレンド/公開フィードの1件を表す。
struct NowPlaying: Identifiable, Codable, Sendable, Equatable {
    let userId: String
    var id: String { userId }
    var displayName: String?          // 共有者の表示名（フィード用に非正規化）
    var service: String               // MusicService.rawValue
    var trackTitle: String
    var artist: String?
    var artworkUrl: String?
    var startedAt: Date?
    var updatedAt: Date
    var visibility: String            // "private" | "public"

    var serviceKind: MusicService { MusicService(rawValue: service) ?? .manual }
    var isShared: Bool { visibility == "public" }
}

// MARK: - Persistence (UserDefaults に保存するゲーム進行)

/// トラックごとの可変進行（静的フィールドは seed 側を使うため保存しない）
struct TrackProgress: Codable {
    let ownedPieces: [Int]
    let isUnlocked: Bool
    let hintLevel: Int
    let answerReady: Bool
    let title: String?
    let artistName: String?
}

/// 端末に保存するセーブデータ全体。
/// 項目追加で旧セーブが壊れない（=進行リセットしない）よう、欠損キーは
/// デフォルト値で補完するトレラントなデコードにしている。
struct SaveState: Codable {
    var trackProgress: [String: TrackProgress] = [:]
    var coins: Int = 240
    var exp: Int = 0
    var oshiTrackIds: [String] = []
    var unlockedTrackIds: [String] = []
    var friends: [Friend] = []
    var premium: Bool = false
    var linkedServices: [String: Bool] = [:]
    var nowPlayingShareMode: String = "off"
    var hintTickets: Int = 0
    var ownedDecorations: [String] = []
    var equippedDecoration: String? = nil
    var notifyImmediate: Bool = true
    var notifyDigest: Bool = false
    var notifyDigestTime: String = "20:00"
    var notifyEncounter: Bool = true
    var notifyMission: Bool = true
    var bgScanEnabled: Bool = true
    var bgScanMode: String = "balanced"
    var bgNightPause: Bool = false
    var encounterCooldowns: [String: Date] = [:]
    var missionCurrent: Int? = nil
    var previewPlays: [String: PreviewRecord] = [:]
    var customImages: [String: String] = [:]   // trackId -> base64 JPEG（本人画面のみ表示）
    var avatarImage: String? = nil              // プロフィールアイコン base64

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = SaveState()
        d.trackProgress     = (try? c.decode([String: TrackProgress].self, forKey: .trackProgress)) ?? d.trackProgress
        d.coins             = (try? c.decode(Int.self, forKey: .coins)) ?? d.coins
        d.exp               = (try? c.decode(Int.self, forKey: .exp)) ?? d.exp
        d.oshiTrackIds      = (try? c.decode([String].self, forKey: .oshiTrackIds)) ?? d.oshiTrackIds
        d.unlockedTrackIds  = (try? c.decode([String].self, forKey: .unlockedTrackIds)) ?? d.unlockedTrackIds
        d.friends           = (try? c.decode([Friend].self, forKey: .friends)) ?? d.friends
        d.premium           = (try? c.decode(Bool.self, forKey: .premium)) ?? d.premium
        d.linkedServices    = (try? c.decode([String: Bool].self, forKey: .linkedServices)) ?? d.linkedServices
        d.nowPlayingShareMode = (try? c.decode(String.self, forKey: .nowPlayingShareMode)) ?? d.nowPlayingShareMode
        d.hintTickets       = (try? c.decode(Int.self, forKey: .hintTickets)) ?? d.hintTickets
        d.ownedDecorations  = (try? c.decode([String].self, forKey: .ownedDecorations)) ?? d.ownedDecorations
        d.equippedDecoration = (try? c.decode(String?.self, forKey: .equippedDecoration)) ?? d.equippedDecoration
        d.notifyImmediate   = (try? c.decode(Bool.self, forKey: .notifyImmediate)) ?? d.notifyImmediate
        d.notifyDigest      = (try? c.decode(Bool.self, forKey: .notifyDigest)) ?? d.notifyDigest
        d.notifyDigestTime  = (try? c.decode(String.self, forKey: .notifyDigestTime)) ?? d.notifyDigestTime
        d.notifyEncounter   = (try? c.decode(Bool.self, forKey: .notifyEncounter)) ?? d.notifyEncounter
        d.notifyMission     = (try? c.decode(Bool.self, forKey: .notifyMission)) ?? d.notifyMission
        d.bgScanEnabled     = (try? c.decode(Bool.self, forKey: .bgScanEnabled)) ?? d.bgScanEnabled
        d.bgScanMode        = (try? c.decode(String.self, forKey: .bgScanMode)) ?? d.bgScanMode
        d.bgNightPause      = (try? c.decode(Bool.self, forKey: .bgNightPause)) ?? d.bgNightPause
        d.encounterCooldowns = (try? c.decode([String: Date].self, forKey: .encounterCooldowns)) ?? d.encounterCooldowns
        d.missionCurrent    = (try? c.decode(Int?.self, forKey: .missionCurrent)) ?? d.missionCurrent
        d.previewPlays      = (try? c.decode([String: PreviewRecord].self, forKey: .previewPlays)) ?? d.previewPlays
        d.customImages      = (try? c.decode([String: String].self, forKey: .customImages)) ?? d.customImages
        d.avatarImage       = (try? c.decode(String?.self, forKey: .avatarImage)) ?? d.avatarImage
        self = d
    }
}

/// ピース取得直後に表示するフレンド申請カードの対象
struct PendingFriend: Equatable {
    let userId: String
    let userName: String
    let locationLabel: String
}

/// 試聴回数の記録（1曲1日3回まで）
struct PreviewRecord: Codable {
    let date: String   // "yyyy-MM-dd"
    var count: Int
}

// MARK: - Title / Achievement

struct TitleItem: Identifiable {
    let id: String
    let icon: String
    let name: String
    let description: String
    let rewardCoins: Int
    let rewardExp: Int
    let conditionType: String   // "puzzles" | "artists" | "friends" | "unlocks" | "mission"
    let conditionCount: Int
}

// MARK: - Artist Group (computed locally)

struct ArtistGroup: Identifiable {
    let id: String
    let name: String
    var tracks: [Track]
    var completed: Int { tracks.filter { $0.isComplete }.count }
}

// MARK: - Shop Item

struct ShopItem: Identifiable {
    let id: String
    let icon: String
    let name: String
    let description: String
    let price: Int
    let type: String    // "ticket" | "piece" | "decoration"
}

// MARK: - Ranking Row

struct RankRow: Identifiable {
    let id = UUID()
    let name: String
    let sub: String
    let count: Int
    let isMe: Bool
}

// MARK: - BLE

struct NearbyUser: Identifiable {
    let id: String
    let userId: String
    let rssi: Int
    let detectedAt: Date
}
