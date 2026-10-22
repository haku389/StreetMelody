import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: AppViewModel
    @AppStorage("streetmelody.discoveryGuide.v1") private var guideFinished = false
    @State private var guideStep = 0
    @ObservedObject private var music = MusicConnectManager.shared

    var body: some View {
        // 上段（プロフィール）はスクロールで隠れ、レベルは上端に残す（StyleCare の LevelBar と同じ）
        MLTabScreen {
            headerRow
        } pinned: {
            levelBar
        } content: {
            VStack(spacing: 0) {
                if !guideFinished { firstDiscoveryGuide.padding(.bottom, 20) }
                MLWelcomeHero { vm.activeTab = .melody }
                    .padding(.bottom, 20)
                notificationBanner
                nearlyCompletePanel
                nowPlayingPanel
                heroPanel
                collectionPanel
                missionPanel
                recentTracksPanel
                discoveryBanner
            }
        }
    }

    private var firstDiscoveryGuide: some View {
        let titles = ["好きな曲を、誰かのきっかけに。", "すれちがいが、ピースになる。", "あと少しを、今日の楽しみに。"]
        let descriptions = ["マイページで推し曲を選ぶと、あなたの好きな音楽を届けられます。", "届いたメロディから曲を選び、まだ持っていないピースを集めましょう。", "集めかけの曲はホームから確認できます。まずは最初の出会いを見てみましょう。"]
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("はじめてのStreetMelody").font(.system(size: 10, weight: .semibold)).foregroundStyle(MLPalette.muted)
                Spacer()
                Button("あとで") { guideFinished = true }.font(.system(size: 11)).foregroundStyle(MLPalette.muted)
            }
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Capsule().fill(index == guideStep ? MLPalette.primary : MLPalette.lilac).frame(width: index == guideStep ? 28 : 8, height: 5)
                }
                Spacer()
                Text("\(guideStep + 1) / 3").font(.system(size: 10)).foregroundStyle(MLPalette.muted)
            }
            Text(titles[guideStep]).font(.system(size: 20, weight: .bold)).foregroundStyle(MLPalette.ink)
            Text(descriptions[guideStep]).font(.system(size: 12)).foregroundStyle(MLPalette.muted).fixedSize(horizontal: false, vertical: true)
            HStack {
                if guideStep > 0 { Button("戻る") { guideStep -= 1 }.font(.system(size: 12)).foregroundStyle(MLPalette.muted) }
                Spacer()
                Button(guideStep < 2 ? "次へ" : "届いたメロディを見る") {
                    if guideStep < 2 { guideStep += 1 }
                    else { guideFinished = true; vm.activeTab = .melody }
                }.buttonStyle(MLClayButtonStyle())
            }
        }.padding(20).mlCard()
    }

    @ViewBuilder private var nearlyCompletePanel: some View {
        if !vm.nearlyCompleteTracks.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("あと少しで完成").font(.system(size: 16, weight: .bold)).foregroundStyle(MLPalette.ink)
                        Text("今日の一歩を、この曲に。").font(.system(size: 10)).foregroundStyle(MLPalette.muted)
                    }
                    Spacer()
                    Button("使い方") { guideStep = 0; guideFinished = false }.font(.system(size: 11)).foregroundStyle(MLPalette.primary)
                }
                ForEach(vm.nearlyCompleteTracks) { track in
                    HStack(spacing: 12) {
                        ArtBlockView(track: track, cornerRadius: 10).mlThumbFrame(width: 80)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(track.displayTitle).font(.system(size: 12, weight: .semibold)).foregroundStyle(MLPalette.ink).lineLimit(1)
                            Text("あと\(track.pieceCount - track.ownedPieces.count)ピース · \(track.ownedPieces.count) / \(track.pieceCount)")
                                .font(.system(size: 10)).foregroundStyle(MLPalette.muted)
                            ProgressBarView(value: Double(track.ownedPieces.count) / Double(track.pieceCount))
                        }
                        Button(vm.canContinueCollecting(trackId: track.id) ? "集める" : "見る") { vm.continueCollecting(trackId: track.id) }
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(MLPalette.primary)
                            .padding(10).background(MLPalette.lilac, in: Capsule())
                            .accessibilityLabel("\(track.displayTitle)の\(vm.canContinueCollecting(trackId: track.id) ? "ピースを集める" : "進み具合を見る")")
                    }
                }
            }.padding(18).mlCard().padding(.bottom, 18)
        } else if guideFinished {
            Button("はじめての方へ · 使い方を見る") { guideStep = 0; guideFinished = false }
                .font(.system(size: 11)).foregroundStyle(MLPalette.muted).padding(.bottom, 14)
        }
    }

    private var discoveryBanner: some View {
        Button { vm.activeTab = .melody } label: {
            HStack(spacing: 14) {
                Image(systemName: "star.fill")
                    .font(.system(size: 42)).foregroundStyle(Color(hex: "FFDF8F"))
                    .shadow(color: MLPalette.shadow.opacity(0.25), radius: 2, y: 3)
                VStack(alignment: .leading, spacing: 6) {
                    Text("まだ知らない、好きな音に。")
                        .font(.system(size: 13, weight: .semibold))
                    Text("あなたの世界を広げるメロディを。")
                        .font(.system(size: 10))
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(MLPalette.button, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.5)))
            .mlShadow()
        }
        .buttonStyle(MLPressButtonStyle()).padding(.top, 20)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                // マイページで設定したアイコン（無ければ名前の頭文字）
                UserAvatar(image: vm.avatarUIImage(), name: vm.profile.displayName ?? "", size: 50)
                    .shadow(color: Color(hex: "A27BC8").opacity(0.15), radius: 8, y: 4)
                if let deco = vm.equippedDecoration,
                   let item = vm.shopItems.first(where: { $0.id == deco }) {
                    Text(item.icon).font(.system(size: 16)).offset(x: 6, y: -6)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("YOUR DAILY SOUNDTRACK")
                    .font(.system(size: 7, weight: .semibold)).tracking(1.2)
                    .foregroundStyle(MLPalette.muted)
                Text("こんにちは、\(vm.profile.displayName ?? vm.user?.name ?? "音楽好き")さん ☀︎")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(MLPalette.ink)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
            Spacer()
            coinPill
        }
    }

    /// レベル（上段が隠れても上端に残る）
    private var levelBar: some View {
        let lv = vm.levelInfo()
        return HStack(spacing: 10) {
            Text("Lv.\(lv.level)").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
            ProgressBarView(value: Double(lv.current) / Double(max(lv.next, 1))).frame(height: 6)
            Text("あと\(lv.next - lv.current) EXP")
                .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "B29ABC"))
                .lineLimit(1).fixedSize()
        }
    }

    private var coinPill: some View {
        HStack(spacing: 6) {
            CoinIcon(size: 18)
            Text("\(vm.coins)").font(.system(size: 12, weight: .black)).foregroundStyle(MLPalette.ink)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(hex: "EEE0F2"), in: Capsule())
        .overlay(Capsule().stroke(Color(hex: "EADCE7")))
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
                            .background(Color(hex: "A27BC8"), in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        Text("🔕").font(.system(size: 16))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日\(pending)件のメロディが届いています")
                            .font(.system(size: 12, weight: .black)).foregroundStyle(MLPalette.ink)
                        Text(vm.notifyImmediate
                             ? "パズル候補を確認しましょう"
                             : "即時通知オフ — まとめ通知でお知らせします")
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                    }
                    Spacer()
                    Text("確認する").font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color(hex: "A27BC8"))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(hex: "EEE0F2"), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .mlCard(radius: 18)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color(hex: "9670F0").opacity(0.55), Color(hex: "FF8FB5").opacity(0.45)],
                                                 startPoint: .leading, endPoint: .trailing), lineWidth: 1.2))
            }
            .buttonStyle(MLPressButtonStyle())
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
                        .background(Color(hex: "A27BC8"), in: Capsule())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(np.track.title)
                            .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink).lineLimit(1)
                        if let a = np.track.artist, !a.isEmpty {
                            Text(a).font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "8D7694")).lineLimit(1)
                        }
                    }
                    Spacer()
                    Text("♪ 再生中").font(.system(size: 9, weight: .black))
                        .foregroundStyle(np.track.isPlaying ? Color(hex: "1A9E6E") : Color(hex: "B29ABC"))
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
                            .foregroundStyle(on ? Color(hex: "8D7694") : .white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(on ? Color(hex: "EEE0F2") : Color(hex: "A27BC8"),
                                        in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .foregroundStyle(Color(hex: "A27BC8"))
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
                        ArtBlockView(track: hero, cornerRadius: 14)
                    } else {
                        Color.clear
                            .overlay { Image("PastelRoom").resizable().scaledToFill() }
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .mlThumbFrame(width: 152)

                VStack(alignment: .leading, spacing: 9) {
                    Text("今日のメロディ").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                    Text(vm.heroTrack?.displayTitle ?? "—")
                        .font(.system(size: 14, weight: .black)).lineLimit(2).foregroundStyle(MLPalette.ink)
                    if let hero = vm.heroTrack {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(hero.ownedPieces.count) / \(hero.pieceCount)")
                                .font(.system(size: 17, weight: .black)).foregroundStyle(MLPalette.ink)
                            Text("ピース").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                        }
                        ProgressBarView(value: Double(hero.ownedPieces.count) / Double(max(hero.pieceCount, 1)))
                        let rem = max(hero.pieceCount - hero.ownedPieces.count, 0)
                        Text(rem > 0 ? "あと\(rem)ピースで完成！· プレイリストを見る ›" : "完成！· プレイリストを見る ›")
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694")).lineLimit(2)
                    }
                }
            }
        }
        .buttonStyle(MLPressButtonStyle())
        .padding(16).mlCard().padding(.bottom, 14)
    }

    // MARK: - Collection panel

    private var collectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("コレクション").font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                Spacer()
                Button("すべて見る") { vm.activeTab = .collection }
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "A27BC8"))
            }
            HStack(spacing: 10) {
                let completed = vm.tracks.values.filter { $0.isComplete }.count
                statTile(label: "曲パズル",    value: "\(completed) / \(vm.tracks.count)")
                statTile(label: "アーティスト", tint: MLPalette.rose, value: "\(vm.artistGroups.filter { $0.completed == $0.tracks.count && !$0.tracks.isEmpty }.count) / \(vm.artistGroups.count)")
                statTile(label: "コイン", tint: MLPalette.honey, value: "\(vm.coins)")
            }
        }
        .padding(16).mlCard().padding(.bottom, 14)
    }

    private func statTile(label: String, tint: Color = MLPalette.lilac, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
            Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(MLPalette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 12)
        .mlInset(radius: 18, tint: tint)
    }

    // MARK: - Mission panel

    private var missionPanel: some View {
        Button { vm.navigate(to: .mission) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(vm.mission?.label ?? "デイリー")ミッション")
                            .font(.system(size: 13, weight: .black)).foregroundStyle(MLPalette.ink)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: "B29ABC"))
                    }
                    ProgressBarView(value: vm.mission?.progress ?? 0)
                    let claimed = vm.mission?.claimed ?? false
                    Text(claimed
                         ? "🎉 達成済み！メロディコイン +\(vm.mission?.rewardCoins ?? 30) を獲得しました"
                         : "ピースを\(vm.mission?.target ?? 5)個獲得しよう（達成でコイン +\(vm.mission?.rewardCoins ?? 30)）")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Text("\(vm.mission?.displayCurrent ?? 0) / \(vm.mission?.target ?? 5)")
                    .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
            }
        }
        .buttonStyle(MLPressButtonStyle())
        .padding(16).mlCard().padding(.bottom, 14)
    }

    // MARK: - Recent tracks panel

    private var recentTracksPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近届いた曲").font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                Spacer()
                Button("すべて見る") { vm.activeTab = .melody }
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "A27BC8"))
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
                    .prefix(4)
            )
            if recentTracks.isEmpty {
                Text("まだピースを受け取った曲がありません")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 2), spacing: 12) {
                    ForEach(recentTracks) { track in
                        Button {
                            vm.navigate(to: track.isUnlocked ? .puzzle(trackId: track.id) : .mystery(trackId: track.id))
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtBlockView(track: track, cornerRadius: 14).aspectRatio(ArtBlockView.ratio, contentMode: .fit)
                                Text(track.isUnlocked ? track.title ?? "—" : "未解放メロディ")
                                    .font(.system(size: 11, weight: .black)).lineLimit(1).foregroundStyle(MLPalette.ink)
                                Text(track.displayArtist)
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(Color(hex: "8D7694")).lineLimit(1)
                            }
                        }
                        .buttonStyle(MLPressButtonStyle())
                    }
                }
            }
        }
        .padding(16).mlCard()
    }
}

// MARK: - Format helpers

func formatNumber(_ n: Int) -> String {
    let fmt = NumberFormatter()
    fmt.numberStyle = .decimal
    return fmt.string(from: NSNumber(value: n)) ?? "\(n)"
}
