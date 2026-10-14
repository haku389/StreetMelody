import SwiftUI

// MARK: - カラーバリアント

extension LinearGradient {
    static let mlSunset  = LinearGradient(colors: [Color(hex: "ff9a6c"), Color(hex: "ffca7a"), Color(hex: "6b468c")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlViolet  = LinearGradient(colors: [Color(hex: "c0adff"), Color(hex: "9271f0"), Color(hex: "4f3b82")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlBerry   = LinearGradient(colors: [Color(hex: "ff8eb5"), Color(hex: "bb74ff"), Color(hex: "39436f")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlMagic   = LinearGradient(colors: [Color(hex: "8ee7ff"), Color(hex: "80d8b5"), Color(hex: "365a70")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mlDefault = LinearGradient(colors: [Color(hex: "a892ff"), Color(hex: "ffb0bf"), Color(hex: "33465f")], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xff) / 255,
            green: Double((rgb >> 8)  & 0xff) / 255,
            blue:  Double( rgb        & 0xff) / 255
        )
    }
}

func artGradient(for color: String) -> LinearGradient {
    switch color {
    case "sunset": return .mlSunset
    case "violet": return .mlViolet
    case "berry":  return .mlBerry
    case "magic":  return .mlMagic
    default:       return .mlDefault
    }
}

// MARK: - MelodyCardArtwork（曲アート）
//
// 表示の優先順：本人のカスタム画像 ＞ YouTube サムネイル ＞ 独自生成カード（サムネが無い曲のみ）。
// blur は未解放曲のネタバレ防止（カスタム画像には掛けない）。
struct MelodyCardArtwork: View {
    var color: String = "violet"
    var seed: String = ""
    var thumbnailURL: URL? = nil
    var customImage: UIImage? = nil
    var blur: Bool = false

    private var blurs: Bool { blur && customImage == nil }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                if let ui = customImage {
                    Image(uiImage: ui).resizable().scaledToFill().frame(width: w, height: h).clipped()
                } else if let url = thumbnailURL {
                    artGradient(for: color)            // 読み込み中の下地
                    CachedThumbnail(url: url)
                } else {
                    artGradient(for: color)
                    RadialGradient(colors: [Self.moodColor(seed).opacity(0.5), .clear],
                                   center: .topTrailing, startRadius: 0, endRadius: max(w, h) * 0.95)
                    puzzleGrid(w: w, h: h)
                    waveform(w: w, h: h)
                    Image(systemName: "music.note")
                        .font(.system(size: min(w, h) * 0.26, weight: .black))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
            }
            .frame(width: w, height: h)
            .blur(radius: blurs ? 12 : 0)
            .scaleEffect(blurs ? 1.15 : 1)   // ぼかしの縁が透けないよう少し拡大
        }
        .clipped()
    }

    private func puzzleGrid(w: CGFloat, h: CGFloat) -> some View {
        Path { p in
            for i in 1..<6 { let x = w * CGFloat(i) / 6; p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: h)) }
            for j in 1..<4 { let y = h * CGFloat(j) / 4; p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: w, y: y)) }
        }.stroke(Color.white.opacity(0.18), lineWidth: 0.8)
    }

    private func waveform(w: CGFloat, h: CGFloat) -> some View {
        let bars = Self.bars(seed)
        let n = bars.count
        return HStack(spacing: w / CGFloat(n) * 0.36) {
            ForEach(0..<n, id: \.self) { i in
                Capsule().fill(Color.white.opacity(0.55))
                    .frame(width: w / CGFloat(n) * 0.62, height: max(4, h * 0.5 * bars[i]))
            }
        }
        .frame(width: w, height: h, alignment: .center)
    }

    static func bars(_ seed: String) -> [CGFloat] {
        var h = Track.mlHash(seed.isEmpty ? "melody" : seed)
        return (0..<18).map { _ in
            h = h &* 6364136223846793005 &+ 1442695040888963407
            return 0.25 + CGFloat((h >> 33) % 1000) / 1000 * 0.75
        }
    }
    static func moodColor(_ seed: String) -> Color {
        let palette = ["FFB0BF", "8EE7FF", "C0ADFF", "FFD27A", "80D8B5", "FF8EB5"]
        return Color(hex: palette[Int(Track.mlHash(seed.isEmpty ? "m" : seed) % UInt64(palette.count))])
    }
}

// MARK: - ArtBlockView

/// 曲アート（正方形〜任意比率）。YouTube サムネイルを中央クロップで表示し、
/// 未解放曲はネタバレ防止でモザイク。サムネが無い曲は独自生成カード。
/// customImage は本人画面のみ渡す。
struct ArtBlockView: View {
    var color: String = "violet"
    var cornerRadius: CGFloat = 18
    var seed: String = ""
    var thumbnailURL: URL? = nil
    var mosaic: Bool = false
    var customImage: UIImage? = nil

    init(color: String, cornerRadius: CGFloat = 18, customImage: UIImage? = nil) {
        self.color = color
        self.cornerRadius = cornerRadius
        self.customImage = customImage
    }

    init(track: Track, cornerRadius: CGFloat = 18, customImage: UIImage? = nil) {
        self.color = track.color
        self.cornerRadius = cornerRadius
        self.seed = track.id
        self.thumbnailURL = track.thumbnailURL
        self.mosaic = !track.isUnlocked
        self.customImage = customImage
    }

    var body: some View {
        MelodyCardArtwork(color: color, seed: seed, thumbnailURL: thumbnailURL,
                          customImage: customImage, blur: mosaic)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.white.opacity(0.45), lineWidth: 1))
    }
}

// MARK: - PuzzlePiecesView

/// 設計書準拠の 6×4＝24ピースのパズル表示。
/// 所持ピースだけサムネイル（無ければ独自生成カード）を見せ、未所持は lockedピース（淡い紫）で隠す。
/// - revealAll: フル表示（全ピースを見せる）
/// - blur: モザイク（未解放曲のフル表示などで使用）
/// - customImage: 本人画面のみ。
struct PuzzlePiecesView: View {
    let ownedPieces: [Int]
    var color: String = "violet"
    var seed: String = ""
    var thumbnailURL: URL? = nil
    var customImage: UIImage? = nil
    var cornerRadius: CGFloat = 16
    var revealAll: Bool = false
    var blur: Bool = false

    private let cols = 6
    private let rows = 4
    private let gap: CGFloat = 2

    private func isVisible(_ n: Int) -> Bool { revealAll || ownedPieces.contains(n) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // ベース：未所持ロックピース（淡い紫グレー）
                pieceGrid(w: w, h: h) { _ in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "E3DAF5"))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: "D3C7EE"), lineWidth: 0.5))
                }
                // サムネイル（所持ピースのみマスク表示）
                MelodyCardArtwork(color: color, seed: seed, thumbnailURL: thumbnailURL, customImage: customImage, blur: blur)
                .frame(width: w, height: h)
                .mask(
                    pieceGrid(w: w, h: h) { n in
                        Rectangle().fill(isVisible(n) ? Color.white : Color.clear)
                    }
                )
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color(hex: "E0D8F7")))
    }

    @ViewBuilder
    private func pieceGrid<Cell: View>(w: CGFloat, h: CGFloat, @ViewBuilder cell: @escaping (Int) -> Cell) -> some View {
        VStack(spacing: gap) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(0..<cols, id: \.self) { c in
                        cell(r * cols + c + 1)
                    }
                }
            }
        }
        .frame(width: w, height: h)
    }
}

// MARK: - CachedThumbnail

/// SwiftUI標準の AsyncImage は再描画のたびにロードをやり直し、
/// 読み込み中はプレースホルダ（=下のグラデーション）に戻ってしまう。
/// NSCache + @State で一度読み込んだ画像を保持し、再描画でも消えないようにする。
final class ThumbnailCache {
    static let shared = NSCache<NSURL, UIImage>()
}

/// QUIC スタール対策＋タイムアウト付きの専用セッション。
/// シミュレータで img.youtube への HTTP/3 接続がハングする事象を回避する。
private let thumbnailSession: URLSession = {
    let cfg = URLSessionConfiguration.default
    cfg.timeoutIntervalForRequest = 12
    cfg.timeoutIntervalForResource = 20
    cfg.waitsForConnectivity = true
    cfg.requestCachePolicy = .returnCacheDataElseLoad
    return URLSession(configuration: cfg)
}()

struct CachedThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        // Color.clear を基準にすることで、コンテナの形（正方形/16:9）に必ず追従させる。
        // 画像を overlay にすると画像自身がレイアウトサイズを決めなくなり、
        // scaledToFill でその枠を埋めて中央クロップされる（正方形なら 1:1 クロップ）。
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .onAppear {
                if image == nil,
                   let cached = ThumbnailCache.shared.object(forKey: url as NSURL) {
                    image = cached
                }
            }
            .task(id: url) { await load() }
    }

    private func load() async {
        // ビューが別URLで再利用されたとき、前の画像が残らないよう必ず更新する
        if let cached = ThumbnailCache.shared.object(forKey: url as NSURL) {
            image = cached
            return
        }
        image = nil   // 取得中は前トラックの画像を消す（取り違え防止）

        // 同梱画像（file URL）はディスクから直接読む。ネットワーク不要・即時。
        if url.isFileURL {
            guard let data = try? Data(contentsOf: url),
                  let ui = UIImage(data: data) else { return }
            ThumbnailCache.shared.setObject(ui, forKey: url as NSURL)
            image = ui
            return
        }

        guard let (data, _) = try? await thumbnailSession.data(from: url),
              let ui = UIImage(data: data) else { return }
        ThumbnailCache.shared.setObject(ui, forKey: url as NSURL)
        image = ui
    }
}

// MARK: - PieceMeterView

struct PieceMeterView: View {
    let owned: Int
    let total: Int
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text("\(owned) / \(total)")
                .font(.system(size: compact ? 17 : 20, weight: .black))
            Text("ピース")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color(hex: "817992"))
        }
    }
}

// MARK: - ProgressBarView

struct ProgressBarView: View {
    let value: Double   // 0.0 – 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: "eee6fb"))
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "8f6df4"), Color(hex: "ff7fa6")],
                                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 8)
    }
}
