import SwiftUI

struct ArtistDetailView: View {
    let artistId: String
    @EnvironmentObject var vm: AppViewModel

    private var group: ArtistGroup? {
        vm.artistGroups.first { $0.id == artistId }
    }

    var body: some View {
        ScrollView {
            if let group = group {
                VStack(spacing: 0) {
                    artistHero(group: group)
                    trackList(group: group)
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 112)
            } else {
                Text("アーティストが見つかりません")
                    .foregroundStyle(Color(hex: "7B6F8A"))
                    .padding(.top, 60)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .mlNavBarBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "7248E0"))
                }
            }
        }
    }

    // MARK: - Artist hero

    private func artistHero(group: ArtistGroup) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(Color(hex: "EDE8FF"))
                .frame(width: 64, height: 64)
                .overlay(Text("🎵").font(.title))

            VStack(alignment: .leading, spacing: 6) {
                Text(group.name).font(.system(size: 16, weight: .black)).foregroundStyle(.primary)
                Text("曲パズル完成数").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(group.completed)").font(.system(size: 20, weight: .black)).foregroundStyle(.primary)
                    Text("/ \(group.tracks.count) 曲完成").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
                ProgressBarView(value: Double(group.completed) / Double(max(group.tracks.count, 1)))
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 16)
    }

    // MARK: - Track list

    private func trackList(group: ArtistGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("曲パズル一覧")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color(hex: "7B6F8A"))
                .tracking(1)

            VStack(spacing: 10) {
                ForEach(group.tracks) { track in
                    Button {
                        vm.navigate(to: track.isUnlocked ? .puzzle(trackId: track.id) : .mystery(trackId: track.id))
                    } label: {
                        HStack(spacing: 12) {
                            ArtBlockView(track: track, cornerRadius: 14).frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.isUnlocked ? track.title ?? "—" : "未解放メロディ")
                                    .font(.system(size: 13, weight: .black)).lineLimit(1).foregroundStyle(.primary)
                                Text(track.displayArtist).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                                ProgressBarView(value: Double(track.ownedPieces.count) / Double(max(track.pieceCount, 1)))
                                    .frame(height: 4)
                            }
                            Spacer()
                            let done = track.isComplete
                            Text(done ? "完成!" : "\(track.ownedPieces.count)/\(track.pieceCount)")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(done ? Color(hex: "1A9E6E") : Color(hex: "7B6F8A"))
                        }
                        .padding(12)
                        .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "E0D8F7")))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
