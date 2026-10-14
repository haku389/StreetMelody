import SwiftUI
import WebKit
import AVFoundation

// 30秒試聴は iTunes Search の previewUrl を AVPlayer で再生する（下の PreviewPlayerView）。
// 旧 YouTube 音声のみ再生（YouTubeAudioPlayer）は著作権方針により撤去。
// 完成パズルの MV（映像つき）は YouTube 公式埋め込みを使用（YouTubeVideoPlayer）。

// MARK: - YouTube MV（映像つきフルプレイヤー：完成パズル用）

struct YouTubeVideoPlayer: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.scrollView.isScrollEnabled = false
        wv.backgroundColor = .black
        wv.isOpaque = true
        let html = """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>html,body{margin:0;padding:0;background:#000;}iframe{width:100%;height:100%;border:0;}</style>
        </head><body>
        <iframe src="https://www.youtube.com/embed/\(videoId)?playsinline=1&rel=0&modestbranding=1&autoplay=1"
          allow="autoplay; encrypted-media" allowfullscreen></iframe>
        </body></html>
        """
        wv.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
        return wv
    }
    func updateUIView(_ wv: WKWebView, context: Context) {}
}

struct YouTubeMVView: View {
    @EnvironmentObject var vm: AppViewModel
    let trackId: String
    private var track: Track? { vm.track(for: trackId) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button { vm.endMV() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .heavy)).foregroundStyle(.white.opacity(0.8))
                            .frame(width: 36, height: 36).background(.white.opacity(0.12), in: Circle())
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16)
                Spacer()
                if let t = track, let vid = t.youtubeVideoId {
                    YouTubeVideoPlayer(videoId: vid)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 12)
                }
                VStack(spacing: 4) {
                    Text(track?.title ?? "—").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                    Text(track?.displayArtist ?? "—").font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "a78bf8"))
                }
                Spacer()
            }
        }
        .onAppear {
            let s = AVAudioSession.sharedInstance()
            try? s.setCategory(.playback, mode: .moviePlayback); try? s.setActive(true)
        }
    }
}

// MARK: - 試聴モーダル

struct PreviewPlayerView: View {
    @EnvironmentObject var vm: AppViewModel
    let trackId: String

    @State private var secondsLeft = 30
    @State private var finished = false
    @State private var waveAnimate = false
    @State private var player: AVPlayer? = nil
    @State private var loadFailed = false

    private let total = 30
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var track: Track? { vm.track(for: trackId) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "1a1030"), Color(hex: "0f0a20")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            content
        }
        .onReceive(timer) { _ in tick() }
        .onAppear { waveAnimate = true; Task { await startPlayback() } }
        .onDisappear { player?.pause(); player = nil }
    }

    /// iTunes の30秒プレビュー音源を AVPlayer で再生（YouTube埋め込みより確実に鳴る）。
    private func startPlayback() async {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default)
        try? s.setActive(true)
        guard let t = track else { loadFailed = true; return }
        // マスク対象でも検索には実データ（title/artistName）を使う
        let title = t.title ?? t.maskedLabel ?? ""
        let artist = t.artistName ?? ""
        guard !title.isEmpty, let url = await ITunesSearch.previewURL(title: title, artist: artist) else {
            loadFailed = true
            return
        }
        let p = AVPlayer(url: url)
        p.volume = 1.0
        player = p
        p.play()
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { end() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .heavy)).foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.1), in: Circle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 16)

            Spacer()

            // 波形アニメーション（オーディオプレイヤー風）
            HStack(spacing: 5) {
                ForEach(0..<13, id: \.self) { i in
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "b79cff"), Color(hex: "8f6df4")],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 5, height: barHeight(i))
                        .animation(finished ? .default
                                   : .easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.06),
                                   value: waveAnimate)
                }
            }
            .frame(height: 80)
            .opacity(finished ? 0.3 : 1)
            .padding(.bottom, 28)

            Text(track.map { $0.isUnlocked ? ($0.title ?? "—") : $0.maskedTitle(hintLevel: $0.hintLevel) } ?? "未解放メロディ")
                .font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(track?.displayArtist ?? "—")
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "a78bf8"))
                .padding(.top, 4)

            // カウントダウン
            Text(finished ? "完了" : "\(secondsLeft)")
                .font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(.white)
                .padding(.top, 20)
            Text("秒").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white.opacity(0.5))

            // プログレスバー
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "8f6df4"), Color(hex: "ff7fa6")],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(secondsLeft) / CGFloat(total))
                        .animation(.linear(duration: 1), value: secondsLeft)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 40).padding(.top, 18)

            Text(track?.isUnlocked == true ? "解放済み（無制限で試聴できます）"
                                            : "本日あと \(vm.previewPlaysLeft(trackId: trackId)) 回試聴できます")
                .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white.opacity(0.5))
                .padding(.top, 14)

            if loadFailed {
                Text("この曲の試聴音源が見つかりませんでした")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 14)
            } else if finished {
                Text("試聴おわり。ヒントや確認で曲名を当てよう")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 14)
            }

            // 外部音楽サービスで開く（試聴の近くに配置）
            if let t = track {
                HStack(spacing: 10) {
                    extLink("Apple Music", icon: "music.note") {
                        ExternalMusic.openAppleMusic(title: t.title ?? "", artist: t.artistName ?? "")
                    }
                    extLink("Spotify", icon: "music.note") {
                        ExternalMusic.openSpotify(title: t.title ?? "", artist: t.artistName ?? "")
                    }
                }
                .padding(.horizontal, 36).padding(.top, 16)
            }

            Spacer()

            Button { end() } label: {
                Text(finished ? "閉じる" : "停止する")
                    .font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24).padding(.bottom, 28)
        }
    }

    private func extLink(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: icon); Text(label) }
                .font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }

    private func barHeight(_ i: Int) -> CGFloat {
        if finished { return 10 }
        let base: [CGFloat] = [22, 44, 30, 60, 38, 70, 50, 70, 38, 60, 30, 44, 22]
        return waveAnimate ? base[i % base.count] : 12
    }

    private func tick() {
        guard !finished else { return }
        if loadFailed { finished = true; return }
        if secondsLeft > 0 { secondsLeft -= 1 }
        if secondsLeft <= 0 {
            finished = true
            player?.pause()
        }
    }

    private func end() {
        player?.pause()
        vm.endPreview()
    }
}
