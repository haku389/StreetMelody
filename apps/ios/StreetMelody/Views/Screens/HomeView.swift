import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: AppViewModel
    @ObservedObject private var music = MusicConnectManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerRow
                notificationBanner
                nowPlayingPanel
                heroPanel
                collectionPanel
                missionPanel
                recentTracksPanel
                    .padding(.bottom, 112)
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color(hex: "EDE8FF"))
                    .frame(width: 54, height: 54)
                    .overlay(Text("🎵").font(.title2))
                    .shadow(color: Color(hex: "7248E0").opacity(0.15), radius: 8, y: 4)
                if let deco = vm.equippedDecoration,
                   let item = vm.shopItems.first(where: { $0.id == deco }) {
                    Text(item.icon).font(.system(size: 16)).offset(x: 6, y: -6)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.user?.name ?? "StreetMelodyユーザー")
                    .font(.system(size: 15, weight: .black)).foregroundStyle(.primary)
                let lv = vm.levelInfo()
                Text("Lv.\(lv.level)").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                ProgressBarView(value: Double(lv.current) / Double(max(lv.next, 1))).frame(height: 6)
            }
            Spacer()
            coinPill
        }
        .padding(.bottom, 18)
    }

    private var coinPill: some View {
        HStack(spacing: 6) {
            Text("🪙")
            Text("\(vm.coins)").font(.system(size: 12, weight: .black)).foregroundStyle(.primary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(hex: "EDE8FF"), in: Capsule())
        .overlay(Capsule().stroke(Color(hex: "E0D8F7")))
    }

    // MARK: - Notification banner

    @ViewBuilder
    private var notificationBanner: some View {
        let pending = vm.pendingEncounterCount
        if pending > 0 {
            Button { vm.activeTab = .melody } label: {
                HStack(spacing: 10) {
                    if vm.notifyImmediate {
                        Text("NEW").font(.system(size: 9, weight: .black)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(hex: "7248E0"), in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        Text("🔕").font(.system(size: 16))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日\(pending)件のメロディが届いています")
                            .font(.system(size: 12, weight: .black)).foregroundStyle(.primary)
                        Text(vm.notifyImmediate
                             ? "パズル候補を確認しましょう"
                             : "即時通知オフ — まとめ通知でお知らせします")
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                    }
                    Spacer()
                    Text("確認する").font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color(hex: "7248E0"))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "7248E0").opacity(0.35)))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Hero panel

    // MARK: - Now playing（今再生中・ライブ・操作可）

    @ViewBuilder private var nowPlayingPanel: some View {
        if let np = music.active {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(np.service.displayName)
                        .font(.system(size: 9, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color(hex: "7248E0"), in: Capsule())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(np.track.title)
                            .font(.system(size: 14, weight: .black)).foregroundStyle(.primary).lineLimit(1)
                        if let a = np.track.artist, !a.isEmpty {
                            Text(a).font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A")).lineLimit(1)
                        }
                    }
                    Spacer()
                    Text("♪ 再生中").font(.system(size: 9, weight: .black))
                        .foregroundStyle(np.track.isPlaying ? Color(hex: "1A9E6E") : Color(hex: "B8ACD6"))
                }
                HStack(spacing: 22) {
                    Button { vm.musicPrevious() } label: {
                        Image(systemName: "backward.fill").font(.system(size: 18, weight: .bold))
                    }
                    Button { vm.musicTogglePlayPause() } label: {
                        Image(systemName: np.track.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 22, weight: .bold))
                    }
                    Button { vm.musicNext() } label: {
                        Image(systemName: "forward.fill").font(.system(size: 18, weight: .bold))
                    }
                    Spacer()
                    Menu {
                        Button("オフ") { vm.setNowPlayingShareMode("off") }
                        Button("ベストフレンド") { vm.setNowPlayingShareMode("bestfriends") }
                        Button("フレンド") { vm.setNowPlayingShareMode("friends") }
                        Button("全体に公開") { vm.setNowPlayingShareMode("public") }
                    } label: {
                        let on = vm.nowPlayingShareMode != "off"
                        let label = vm.nowPlayingShareMode == "bestfriends" ? "共有: ベスト"
                                  : vm.nowPlayingShareMode == "friends" ? "共有: フレンド"
                                  : vm.nowPlayingShareMode == "public" ? "共有: 公開" : "共有する"
                        Text(label)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(on ? Color(hex: "7B6F8A") : .white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(on ? Color(hex: "EDE8FF") : Color(hex: "7248E0"),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .foregroundStyle(Color(hex: "7248E0"))
            }
            .padding(16).mlCard()
            .padding(.bottom, 14)
        }
    }

    private var heroPanel: some View {
        Button { vm.navigate(to: .playlist) } label: {
            HStack(spacing: 16) {
                Group {
                    if let hero = vm.heroTrack {
                        ArtBlockView(track: hero)
                    } else {
                        RoundedRectangle(cornerRadius: 18).fill(Color(hex: "EDE8FF"))
                    }
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 9) {
                    Text("今日のメロディ").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                    Text(vm.heroTrack?.displayTitle ?? "—")
                        .font(.system(size: 14, weight: .black)).lineLimit(2).foregroundStyle(.primary)
                    if let hero = vm.heroTrack {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(hero.ownedPieces.count) / \(hero.pieceCount)")
                                .font(.system(size: 17, weight: .black)).foregroundStyle(.primary)
                            Text("ピース").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        }
                        ProgressBarView(value: Double(hero.ownedPieces.count) / Double(max(hero.pieceCount, 1)))
                        let rem = max(hero.pieceCount - hero.ownedPieces.count, 0)
                        Text(rem > 0 ? "あと\(rem)ピースで完成！· プレイリストを見る ›" : "完成！· プレイリストを見る ›")
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A")).lineLimit(2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(16).mlCard().padding(.bottom, 14)
    }

    // MARK: - Collection panel

    private var collectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("コレクション").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                Spacer()
                Button("すべて見る") { vm.activeTab = .collection }
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7248E0"))
            }
            HStack(spacing: 10) {
                let completed = vm.tracks.values.filter { $0.isComplete }.count
                statTile(label: "曲パズル",    value: "\(completed) / \(vm.tracks.count)")
                statTile(label: "アーティスト", value: "\(vm.artistGroups.filter { $0.completed == $0.tracks.count && !$0.tracks.isEmpty }.count) / \(vm.artistGroups.count)")
                statTile(label: "コイン",      value: "\(vm.coins)")
            }
        }
        .padding(16).mlCard().padding(.bottom, 14)
    }

    private func statTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            Text(value).font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 12)
        .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Mission panel

    private var missionPanel: some View {
        Button { vm.navigate(to: .mission) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(vm.mission?.label ?? "デイリー")ミッション")
                            .font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: "B8ACD6"))
                    }
                    ProgressBarView(value: vm.mission?.progress ?? 0)
                    let claimed = vm.mission?.claimed ?? false
                    Text(claimed
                         ? "🎉 達成済み！メロディコイン +\(vm.mission?.rewardCoins ?? 30) を獲得しました"
                         : "ピースを\(vm.mission?.target ?? 5)個獲得しよう（達成でコイン +\(vm.mission?.rewardCoins ?? 30)）")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Text("\(vm.mission?.displayCurrent ?? 0) / \(vm.mission?.target ?? 5)")
                    .font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .padding(16).mlCard().padding(.bottom, 14)
    }

    // MARK: - Recent tracks panel

    private var recentTracksPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近届いた曲").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                Spacer()
                Button("すべて見る") { vm.activeTab = .melody }
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7248E0"))
            }
            // Dictionary.values は順序が不定なので、解放済み（=サムネイルを持つ曲）を
            // 優先しつつ id で安定ソートし、毎回同じ並びになるようにする
            let recentTracks = Array(
                vm.tracks.values
                    .filter { !$0.ownedPieces.isEmpty }
                    .sorted { a, b in
                        if a.isUnlocked != b.isUnlocked { return a.isUnlocked }
                        return a.id < b.id
                    }
                    .prefix(3)
            )
            if recentTracks.isEmpty {
                Text("まだピースを受け取った曲がありません")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 12) {
                    ForEach(recentTracks) { track in
                        Button {
                            vm.navigate(to: track.isUnlocked ? .puzzle(trackId: track.id) : .mystery(trackId: track.id))
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtBlockView(track: track).aspectRatio(1, contentMode: .fit)
                                Text(track.isUnlocked ? track.title ?? "—" : "未解放メロディ")
                                    .font(.system(size: 11, weight: .black)).lineLimit(1).foregroundStyle(.primary)
                                Text(track.displayArtist)
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(Color(hex: "7B6F8A")).lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16).mlCard()
    }
}

// MARK: - Card modifier

extension View {
    func mlCard() -> some View {
        self
            .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: "E0D8F7")))
            .shadow(color: Color(hex: "7248E0").opacity(0.07), radius: 12, y: 4)
    }
}

// MARK: - Format helpers

func formatNumber(_ n: Int) -> String {
    let fmt = NumberFormatter()
    fmt.numberStyle = .decimal
    return fmt.string(from: NSNumber(value: n)) ?? "\(n)"
}
