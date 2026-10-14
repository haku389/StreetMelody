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
                    ProgressView().padding(.top, 60).tint(Color(hex: "7248E0"))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .mlNavBarBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "7248E0"))
                }
            }
        }
    }

    private var navHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日のメロディ").font(.system(size: 20, weight: .black)).foregroundStyle(.primary)
                Text(vm.dailyPlaylist?.date ?? "").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
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
                    ArtBlockView(track: t)
                } else {
                    RoundedRectangle(cornerRadius: 18).fill(Color(hex: "EDE8FF"))
                }
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 8) {
                Text("プレイリスト").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                Text(playlist.title).font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                Text("\(playlist.tracks.count)曲").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 16)
    }

    private func trackSection(playlist: DailyPlaylist) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("曲一覧").font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "7B6F8A")).tracking(1)
            ForEach(Array(playlist.tracks.enumerated()), id: \.offset) { i, item in
                if let track = vm.track(for: item.trackId) {
                    Button {
                        vm.navigate(to: track.isUnlocked ? .puzzle(trackId: track.id) : .mystery(trackId: track.id))
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(i + 1)").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "B8ACD6")).frame(width: 20)
                            ArtBlockView(track: track, cornerRadius: 12).frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.isUnlocked ? track.title ?? "—" : "未解放メロディ")
                                    .font(.system(size: 12, weight: .black)).lineLimit(1).foregroundStyle(.primary)
                                Text(track.displayArtist).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Color(hex: "B8ACD6"))
                        }
                        .padding(12)
                        .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "E0D8F7")))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
