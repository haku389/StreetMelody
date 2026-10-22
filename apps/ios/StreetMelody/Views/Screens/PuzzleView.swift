import SwiftUI
import PhotosUI

struct PuzzleView: View {
    let trackId: String
    @EnvironmentObject var vm: AppViewModel
    @State private var photoItem: PhotosPickerItem?

    private var track: Track? { vm.track(for: trackId) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let t = track { content(track: t) }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(MLBackground())
        .navigationBarBackButtonHidden(true)
        .mlNavBarBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "A27BC8"))
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(track?.displayTitle ?? "—")
                        .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink).lineLimit(1)
                    Text(track?.displayArtist ?? "—")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await vm.addListenLater(trackId: trackId) } } label: {
                    Image(systemName: "heart").font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "A27BC8"))
                }
            }
        }
    }

    private func content(track: Track) -> some View {
        let owned    = track.ownedPieces.count
        let total    = track.pieceCount
        let progress = Double(owned) / Double(max(total, 1))
        let rem      = max(total - owned, 0)

        return VStack(spacing: 14) {
            // 6×4 パズル本体：所持ピースだけサムネイルが見える（設計書準拠）
            VStack(spacing: 14) {
                PuzzlePiecesView(ownedPieces: track.ownedPieces,
                                 color: track.color,
                                 seed: track.id,
                                 thumbnailURL: track.thumbnailURL,
                                 customImage: vm.customUIImage(for: track.id),
                                 cornerRadius: 18)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(owned) / \(total)").font(.system(size: 20, weight: .black)).foregroundStyle(MLPalette.ink)
                        Text("ピース").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                        Spacer()
                        Text(rem > 0 ? "あと\(rem)ピースで完成！" : "🎉 完成！")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(rem == 0 ? Color(hex: "1A9E6E") : Color(hex: "8D7694"))
                    }
                    ProgressBarView(value: progress)
                }
            }
            .padding(16).mlCard()

            musicActions(track: track)

            customImageSection(track: track)

            VStack(alignment: .leading, spacing: 12) {
                Text("完成で手に入る報酬").font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                HStack(spacing: 10) {
                    rewardTile(label: "メロディコイン", value: "×\(track.rewardCoins)")
                    rewardTile(label: "経験値", value: "×\(track.rewardExp)")
                }
                Button { vm.activeTab = .melody } label: {
                    Text("ピースを集める").buttonLabel(.primary)
                }
            }
            .padding(16).mlCard()

            PostCollectSection()
        }
    }

    private func musicActions(track: Track) -> some View {
        let title = track.title ?? track.displayTitle
        let artist = track.artistName ?? track.displayArtist
        return VStack(alignment: .leading, spacing: 12) {
            Text("この曲を聴く・観る").font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
            Text("Apple Music / Spotify アプリで開いて再生できます（バックグラウンド継続）")
                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
            HStack(spacing: 10) {
                actionButton("Apple Music", icon: "music.note", bg: Color(hex: "FA2D48")) {
                    ExternalMusic.openAppleMusic(title: title, artist: artist)
                }
                actionButton("Spotify", icon: "music.note", bg: Color(hex: "1DB954")) {
                    ExternalMusic.openSpotify(title: title, artist: artist)
                }
            }
            HStack(spacing: 10) {
                if track.hasYouTubeVideo {
                    actionButton("30秒試聴", icon: "play.fill", bg: Color(hex: "5BA8F5")) { vm.startPreview(trackId: trackId) }
                }
                if track.isComplete && track.hasYouTubeVideo {
                    actionButton("MVを見る（YouTube）", icon: "play.rectangle.fill", bg: Color(hex: "49335F")) { vm.playMV(trackId: trackId) }
                }
            }
        }
        .padding(16).mlCard()
    }

    private func actionButton(_ label: String, icon: String, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: icon); Text(label) }
                .font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(bg, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func rewardTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
            Text(value).font(.system(size: 20, weight: .black)).foregroundStyle(MLPalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .mlInset(radius: 18)
    }

    // MARK: - カスタムパズル画像（本人の画面のみ。公開には出さない）

    private func customImageSection(track: Track) -> some View {
        let hasCustom = vm.customImages[trackId] != nil
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("パズル画像をカスタマイズ").font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                Spacer()
                Text("本人のみ").font(.system(size: 9, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color(hex: "EEE0F2"), in: Capsule())
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 6) { Image(systemName: "photo"); Text(hasCustom ? "画像を変更" : "画像を選ぶ") }
                        .font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(Color(hex: "A27BC8"), in: RoundedRectangle(cornerRadius: 12))
                }
                if hasCustom {
                    Button { vm.setCustomImage(nil, for: trackId) } label: {
                        Text("解除").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(Color(hex: "EEE0F2"), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(16).mlCard()
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    vm.setCustomImage(ui, for: trackId)
                }
                photoItem = nil
            }
        }
    }
}
