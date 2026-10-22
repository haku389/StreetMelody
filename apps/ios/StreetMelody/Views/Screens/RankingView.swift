import SwiftUI

struct RankingView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        MLTabScreen {
            MLTabTitle(title: "ランキング")
        } pinned: {
            tabSwitcher
        } content: {
            VStack(spacing: 18) {
                let rows = vm.rankRows(for: vm.rankingTab)
                let rank = rows.firstIndex(where: { $0.isMe }).map { "\($0 + 1)位" } ?? "—"
                MLTabSummary(symbol: "star.fill", title: "小さなピースが、今日の一歩に。", caption: "音楽との出会いを、みんなと楽しもう。", metrics: [("あなたの順位", vm.rankingTab == .friend && vm.friends.isEmpty ? "—" : rank), ("集めたピース", "\(vm.tracks.values.reduce(0) { $0 + $1.ownedPieces.count })枚")])
                rankingContent
            }
        }
    }

    // MARK: - Header

    // MARK: - Tab switcher

    private var tabSwitcher: some View {
        GlassSegment(items: RankingTab.allCases, selection: $vm.rankingTab) { $0.rawValue }
    }

    // MARK: - Ranking content

    @ViewBuilder
    private var rankingContent: some View {
        let tab = vm.rankingTab

        if tab == .near && !vm.premium {
            HStack(spacing: 10) {
                Text("📍")
                VStack(alignment: .leading, spacing: 2) {
                    Text("エリアランキング").font(.system(size: 12, weight: .black)).foregroundStyle(MLPalette.ink)
                    Text("離れたエリアの閲覧はプレミアム機能です").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                }
                Spacer()
                Button("詳細") { vm.navigate(to: .premium) }
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(hex: "A27BC8"), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(14)
            .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "EADCE7")))
            .padding(.bottom, 14)
        }

        if tab == .friend && vm.friends.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "music.note").font(.system(size: 16, weight: .black)).foregroundStyle(MLPalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("まだフレンドがいません").font(.system(size: 12, weight: .black)).foregroundStyle(MLPalette.ink)
                    Text("すれちがいでピースを交換するとフレンドになれます").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                }
                Spacer()
                Button("出会いへ") { vm.activeTab = .melody }
                    .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(hex: "A27BC8"), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(14)
            .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "EADCE7")))
        } else {
            let rows = vm.rankRows(for: tab)
            let myRank = rows.firstIndex(where: { $0.isMe }).map { $0 + 1 } ?? 0

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(tabTitle(tab))
                        .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                    Spacer()
                    Text("集めたピース数 · あなたは\(myRank)位")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                }
                .padding(.bottom, 12)

                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    rankRow(rank: i + 1, row: row)
                    if i < rows.count - 1 {
                        Divider().background(Color(hex: "EADCE7")).padding(.vertical, 2)
                    }
                }
            }
            .padding(14).mlCard()
        }
    }

    private func rankRow(rank: Int, row: RankRow) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(rank <= 3 ? Color(hex: "A27BC8") : Color(hex: "B29ABC"))
                .frame(width: 34, height: 36, alignment: .center)
                .background(rank == 1 ? MLPalette.honey : rank <= 3 ? MLPalette.lilac : MLPalette.cream, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.8)))

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(row.isMe ? MLPalette.primary : MLPalette.ink)
                Text(row.sub)
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
            }

            Spacer()

            Text("\(row.count)枚")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(row.isMe ? Color(hex: "A27BC8") : Color(hex: "8D7694"))
        }
        .padding(.horizontal, row.isMe ? 8 : 0)
        .padding(.vertical, 10)
        .background(row.isMe ? Color(hex: "A27BC8").opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
    }

    private func tabTitle(_ tab: RankingTab) -> String {
        switch tab {
        case .today:  return "今日すれちがった人"
        case .near:   return "近くのエリア"
        case .friend: return "フレンド"
        case .all:    return "全国"
        }
    }
}
