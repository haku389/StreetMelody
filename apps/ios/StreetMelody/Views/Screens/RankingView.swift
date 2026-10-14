import SwiftUI

struct RankingView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                tabSwitcher.padding(.bottom, 14)
                rankingContent
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
            Text("ランキング").font(.system(size: 20, weight: .black)).foregroundStyle(.primary)
            Spacer()
        }
        .padding(.bottom, 14)
    }

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
                    Text("エリアランキング").font(.system(size: 12, weight: .black)).foregroundStyle(.primary)
                    Text("離れたエリアの閲覧はプレミアム機能です").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
                Spacer()
                Button("詳細") { vm.navigate(to: .premium) }
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(hex: "7248E0"), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(14)
            .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "E0D8F7")))
            .padding(.bottom, 14)
        }

        if tab == .friend && vm.friends.isEmpty {
            HStack(spacing: 10) {
                Text("🎵")
                VStack(alignment: .leading, spacing: 2) {
                    Text("まだフレンドがいません").font(.system(size: 12, weight: .black)).foregroundStyle(.primary)
                    Text("すれちがいでピースを交換するとフレンドになれます").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
                Spacer()
                Button("出会いへ") { vm.activeTab = .melody }
                    .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(hex: "7248E0"), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(14)
            .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "E0D8F7")))
        } else {
            let rows = vm.rankRows(for: tab)
            let myRank = rows.firstIndex(where: { $0.isMe }).map { $0 + 1 } ?? 0

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(tabTitle(tab))
                        .font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                    Spacer()
                    Text("集めたピース数 · あなたは\(myRank)位")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
                .padding(.bottom, 12)

                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    rankRow(rank: i + 1, row: row)
                    if i < rows.count - 1 {
                        Divider().background(Color(hex: "E0D8F7")).padding(.vertical, 2)
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
                .foregroundStyle(rank <= 3 ? Color(hex: "7248E0") : Color(hex: "B8ACD6"))
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(row.isMe ? Color(hex: "7248E0") : .primary)
                Text(row.sub)
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }

            Spacer()

            Text("\(row.count)枚")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(row.isMe ? Color(hex: "7248E0") : Color(hex: "7B6F8A"))
        }
        .padding(.horizontal, row.isMe ? 8 : 0)
        .padding(.vertical, 10)
        .background(row.isMe ? Color(hex: "7248E0").opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
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
