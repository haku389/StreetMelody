import SwiftUI

struct CollectionView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                searchBar
                tabSwitcher.padding(.bottom, 14)
                tabContent
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("コレクション")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.bottom, 14)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(Color(hex: "B8ACD6"))
            TextField("曲名・アーティストで検索", text: $searchText)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "E0D8F7")))
        .padding(.bottom, 14)
    }

    // MARK: - Tab switcher

    private var tabSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(CollectionTab.allCases, id: \.self) { tab in
                Button(tab.rawValue) { vm.collectionTab = tab }
                    .font(.system(size: 11, weight: .black))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .foregroundStyle(vm.collectionTab == tab ? Color(hex: "7248E0") : Color(hex: "B8ACD6"))
                    .background(vm.collectionTab == tab ? Color(hex: "7248E0").opacity(0.12) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 14))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(4)
        .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "E0D8F7")))
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch vm.collectionTab {
        case .puzzles: puzzlesTab
        case .artists: artistsTab
        case .oshi:    oshiTab
        case .titles:  titlesTab
        }
    }

    // MARK: - Puzzles tab

    private var puzzlesTab: some View {
        let filtered = searchText.isEmpty ? Array(vm.tracks.values) :
            vm.tracks.values.filter {
                ($0.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.artistName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        let incomplete = filtered.filter { $0.ownedPieces.count < $0.pieceCount }
        let complete   = filtered.filter { $0.ownedPieces.count >= $0.pieceCount }

        return VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("未完成").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                if incomplete.isEmpty {
                    Text("未完成のパズルはありません")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
                ForEach(incomplete.sorted { $0.id < $1.id }) { track in
                    trackRow(track: track)
                }
            }
            .padding(16).mlCard()

            VStack(alignment: .leading, spacing: 12) {
                Text("完成済み").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                if complete.isEmpty {
                    Text("まだ完成したパズルはありません")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                } else {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 12) {
                        ForEach(complete.sorted { $0.id < $1.id }) { track in
                            VStack(alignment: .leading, spacing: 6) {
                                ArtBlockView(track: track, cornerRadius: 14, customImage: vm.customUIImage(for: track.id)).aspectRatio(1, contentMode: .fit)
                                    .overlay(alignment: .bottomTrailing) { playButton(track, size: 26).padding(5) }
                                Text(track.isUnlocked ? track.title ?? "—" : "未解放")
                                    .font(.system(size: 10, weight: .black)).lineLimit(1).foregroundStyle(.primary)
                                Text("完成！").font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "1A9E6E"))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { vm.navigate(to: .puzzle(trackId: track.id)) }
                        }
                    }
                }
            }
            .padding(16).mlCard()
        }
    }

    private func trackRow(track: Track) -> some View {
        HStack(spacing: 12) {
            // タップで詳細へ（再生ボタンとは別領域）
            Button {
                vm.navigate(to: track.isUnlocked ? .puzzle(trackId: track.id) : .mystery(trackId: track.id))
            } label: {
                HStack(spacing: 12) {
                    ArtBlockView(track: track, cornerRadius: 14, customImage: vm.customUIImage(for: track.id)).frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.isUnlocked ? track.title ?? "—" : "未解放メロディ")
                            .font(.system(size: 12, weight: .black)).lineLimit(1).foregroundStyle(.primary)
                        Text(track.displayArtist)
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        ProgressBarView(value: Double(track.ownedPieces.count) / Double(max(track.pieceCount, 1)))
                            .frame(height: 4)
                    }
                    Spacer()
                    Text("\(track.ownedPieces.count)/\(track.pieceCount)")
                        .font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "7B6F8A"))
                }
            }
            .buttonStyle(.plain)
            playButton(track)
        }
    }

    /// 試聴（30秒）ボタン。YouTube動画があり本日の回数が残っていれば再生。
    @ViewBuilder private func playButton(_ track: Track, size: CGFloat = 30) -> some View {
        if track.hasYouTubeVideo {
            Button { vm.startPreview(trackId: track.id) } label: {
                Image(systemName: "play.circle.fill").font(.system(size: size))
                    .foregroundStyle(vm.canPreview(trackId: track.id) ? Color(hex: "7248E0") : Color(hex: "C9BEF0"))
            }
            .buttonStyle(.plain)
            .disabled(!vm.canPreview(trackId: track.id))
        }
    }

    // MARK: - Artists tab

    private var artistsTab: some View {
        VStack(spacing: 14) {
            ForEach(vm.artistGroups) { group in
                artistCard(group: group)
            }
        }
    }

    private func artistCard(group: ArtistGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color(hex: "EDE8FF"))
                        .frame(width: 56, height: 56)
                        .overlay(Text("🎵").font(.title3))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name).font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                        Text("曲パズル完成数").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(group.completed) / \(group.tracks.count)")
                                .font(.system(size: 16, weight: .black)).foregroundStyle(.primary)
                            Text("完成").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        }
                        ProgressBarView(value: Double(group.completed) / Double(max(group.tracks.count, 1)))
                    }
                }
                Spacer()
                Button("詳細 ›") { vm.navigate(to: .artistDetail(artistId: group.id)) }
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color(hex: "7248E0"))
            }
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 10) {
                ForEach(group.tracks) { track in
                    VStack(alignment: .leading, spacing: 6) {
                        ArtBlockView(track: track, cornerRadius: 14, customImage: vm.customUIImage(for: track.id)).aspectRatio(1, contentMode: .fit)
                            .overlay(alignment: .bottomTrailing) { playButton(track, size: 24).padding(5) }
                        Text(track.isUnlocked ? track.title ?? "—" : "未解放")
                            .font(.system(size: 10, weight: .black)).lineLimit(1).foregroundStyle(.primary)
                        let done = track.isComplete
                        Text(done ? "完成!" : track.ownedPieces.isEmpty ? "未入手" : "あと\(track.pieceCount - track.ownedPieces.count)")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(done ? Color(hex: "1A9E6E") : Color(hex: "7B6F8A"))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { vm.navigate(to: track.isUnlocked ? .puzzle(trackId: track.id) : .mystery(trackId: track.id)) }
                }
            }
        }
        .padding(14).mlCard()
    }

    // MARK: - Oshi tab

    private var oshiTab: some View {
        let oshiTracks = vm.oshiTrackIds.compactMap { vm.track(for: $0) }
        return VStack(spacing: 14) {
            if oshiTracks.isEmpty {
                VStack(spacing: 12) {
                    Text("推し曲を設定すると、近距離交換でピースが届きます。\nマイページから設定できます（無料3曲・プレミアム5曲）")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color(hex: "7B6F8A"))
                        .multilineTextAlignment(.center)
                    Button("推し曲を設定する") { vm.activeTab = .mypage }
                        .buttonLabel(.primary)
                }
                .padding(16).mlCard()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("推し曲").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                        Spacer()
                        let limit = vm.premium ? 5 : 3
                        Text("\(oshiTracks.count) / \(limit)曲")
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                    }
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 12) {
                        ForEach(oshiTracks) { track in
                            VStack(alignment: .leading, spacing: 6) {
                                ArtBlockView(track: track, customImage: vm.customUIImage(for: track.id)).aspectRatio(1, contentMode: .fit)
                                Text(track.title ?? "—").font(.system(size: 10, weight: .black)).lineLimit(1).foregroundStyle(.primary)
                                Text(track.displayArtist).font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A")).lineLimit(1)
                            }
                        }
                    }
                    Button("推し曲を編集する") { vm.activeTab = .mypage }
                        .buttonLabel(.secondary)
                }
                .padding(16).mlCard()
            }
        }
    }

    // MARK: - Titles tab

    private var titlesTab: some View {
        let entries = vm.titles
        let unlockedCount = entries.filter { vm.isTitleUnlocked($0) }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("称号").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                Spacer()
                Text("\(unlockedCount) / \(entries.count) 獲得")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            ForEach(entries) { title in
                let unlocked = vm.isTitleUnlocked(title)
                let progress = vm.titleProgress(title)
                HStack(spacing: 12) {
                    Text(title.icon).font(.system(size: 24)).opacity(unlocked ? 1 : 0.4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title.name)
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(unlocked ? Color(hex: "7248E0") : Color(hex: "7B6F8A"))
                        Text(title.description)
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        Text("獲得報酬: 🪙\(title.rewardCoins) · ⭐\(title.rewardExp) EXP")
                            .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "B8ACD6"))
                        if !unlocked {
                            ProgressBarView(value: Double(progress) / Double(max(title.conditionCount, 1)))
                                .frame(height: 4).padding(.top, 2)
                        }
                    }
                    Spacer()
                    Text(unlocked ? "獲得済み" : "\(progress) / \(title.conditionCount)")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(unlocked ? Color(hex: "1A9E6E") : Color(hex: "7B6F8A"))
                }
                .padding(12)
                .background(unlocked ? Color(hex: "7248E0").opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(unlocked ? Color(hex: "7248E0").opacity(0.25) : Color.clear, lineWidth: 1.5))
            }
        }
        .padding(16).mlCard()
    }
}
