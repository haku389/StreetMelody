import SwiftUI

struct FriendDetailView: View {
    let userId: String
    @EnvironmentObject var vm: AppViewModel

    private var friend: Friend? { vm.friends.first { $0.userId == userId } }
    private var encounter: Encounter? { vm.encounters.first { $0.fromUserId == userId } }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let f = friend {
                    profileHeader(friend: f)
                    statsSection(friend: f)
                    if let enc = encounter { sharedTracksSection(encounter: enc) }
                } else {
                    Text("フレンドが見つかりません")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color(hex: "7B6F8A"))
                        .padding(.top, 60)
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
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .heavy)).foregroundStyle(Color(hex: "7248E0"))
                }
            }
            ToolbarItem(placement: .principal) {
                if let f = friend {
                    VStack(spacing: 1) {
                        Text(f.userName).font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                        if let enc = encounter {
                            Text("📍 \(enc.locationLabel)で出会いました")
                                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        }
                    }
                }
            }
        }
    }

    private func profileHeader(friend: Friend) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: "7248E0"))
                .frame(width: 64, height: 64)
                .overlay(Text("🎵").font(.system(size: 24)))

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.userName)
                    .font(.system(size: 16, weight: .black)).foregroundStyle(.primary)
                Text(formatDate(friend.addedAt) + " にフレンドになりました")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            Spacer()
        }
        .padding(.bottom, 18)
    }

    private func statsSection(friend: Friend) -> some View {
        let days = max(1, Int(Date().timeIntervalSince(friend.addedAt) / 86400) + 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                statTile(label: "フレンド歴", value: "\(days)日")
                statTile(label: "交換回数",   value: "\(friend.exchangeCount)回")
                statTile(label: "出会った場所", value: friend.locationLabel)
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            Text(value).font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 12)
        .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 14))
    }

    private func sharedTracksSection(encounter: Encounter) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("音楽でつながった曲")
                .font(.system(size: 14, weight: .black)).foregroundStyle(.primary)

            let sharedTracks = encounter.candidates.compactMap { vm.track(for: $0.trackId) }
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 12) {
                ForEach(sharedTracks) { track in
                    Button {
                        vm.navigate(to: track.isUnlocked ? .puzzle(trackId: track.id) : .mystery(trackId: track.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ArtBlockView(track: track).aspectRatio(1, contentMode: .fit)
                            Text(track.isUnlocked ? track.title ?? "—" : "未解放メロディ")
                                .font(.system(size: 10, weight: .black)).lineLimit(1)
                                .foregroundStyle(.primary)
                            Text(track.displayArtist)
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(Color(hex: "7B6F8A")).lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16).mlCard()
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy/MM/dd"
        return fmt.string(from: date)
    }
}
