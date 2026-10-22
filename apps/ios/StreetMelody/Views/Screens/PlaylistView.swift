import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                navHeader
                if let playlist = vm.dailyPlaylist {
                    playlistHero(playlist: playlist)
                    trackSection(playlist: playlist)
                } else {
                    ProgressView().padding(.top, 60).tint(Color(hex: "A27BC8"))
                }
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
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "A27BC8"))
                }
            }
        }
    }

    private var navHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日のメロディ").font(.system(size: 20, weight: .black)).foregroundStyle(MLPalette.ink)
                Text(vm.dailyPlaylist?.date ?? "").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
            }
            Spacer()
        }
        .padding(.bottom, 18)
    }

    private func playlistHero(playlist: DailyPlaylist) -> some View {
        let heroTrack = playlist.tracks.first.flatMap { vm.track(for: $0.trackId) }
        return HStack(spacing: 16) {
            Group {
                if let t = heroTrack {
                    ArtBlockView(track: t, cornerRadius: 14)
                } else {
                    RoundedRectangle(cornerRadius: 14).fill(Color(hex: "EEE0F2"))
                }
            }
            .mlThumbFrame(width: 152)

            VStack(alignment: .leading, spacing: 8) {
                Text("プレイリスト").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                Text(playlist.title).font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                Text("\(playlist.tracks.count)曲").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 16)
    }

    private func trackSection(playlist: DailyPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("曲一覧").font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "8D7694")).tracking(1)
            ForEach(Array(playlist.tracks.enumerated()), id: \.offset) { i, item in
                if let track = vm.track(for: item.trackId) {
                    Button {
                        vm.navigate(to: track.isUnlocked ? .puzzle(trackId: track.id) : .mystery(trackId: track.id))
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "B29ABC")).frame(width: 20)
                            ArtBlockView(track: track, cornerRadius: 10).mlThumbFrame(width: 72)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.isUnlocked ? track.title ?? "—" : "未解放メロディ")
                                    .font(.system(size: 12, weight: .black)).lineLimit(1).foregroundStyle(MLPalette.ink)
                                Text(track.displayArtist).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Color(hex: "B29ABC"))
                        }
                        .padding(12)
                        .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "EADCE7")))
                    }
                    .buttonStyle(MLPressButtonStyle())
                }
            }
        }
    }
}
