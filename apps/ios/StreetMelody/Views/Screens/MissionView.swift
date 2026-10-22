import SwiftUI

struct MissionView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let m = vm.mission {
                    missionCard(m)
                } else {
                    Text("本日のミッションはありません")
                        .font(.system(size: 13, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                        .frame(maxWidth: .infinity).padding(24).mlCard()
                }

                Button { vm.activeTab = .melody; vm.navigationStack = [] } label: {
                    Text("ピースを集めに行く").buttonLabel(.primary)
                }
            }
            .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(MLBackground())
        .navigationBarBackButtonHidden(true)
        .mlNavBarBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(Color(hex: "A27BC8"))
                }
            }
            ToolbarItem(placement: .principal) {
                Text("デイリーミッション").font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
            }
        }
    }

    private func missionCard(_ m: Mission) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(m.label)ミッション").font(.system(size: 16, weight: .black)).foregroundStyle(MLPalette.ink)
                Spacer()
                if m.claimed {
                    Text("達成済み").font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: "1A9E6E"))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(hex: "1A9E6E").opacity(0.12), in: Capsule())
                }
            }
            Text("ピースを \(m.target) 個 獲得しよう")
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))

            VStack(alignment: .leading, spacing: 6) {
                ProgressBarView(value: m.progress).frame(height: 10)
                HStack {
                    Text("\(m.displayCurrent) / \(m.target)")
                        .font(.system(size: 18, weight: .black)).foregroundStyle(MLPalette.ink)
                    Spacer()
                    Text("報酬：メロディコイン +\(m.rewardCoins)")
                        .font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
                }
            }

            Text(m.claimed
                 ? "🎉 達成おめでとう！報酬を獲得しました。"
                 : "あと \(max(0, m.target - m.current)) 個でクリアです。")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(m.claimed ? Color(hex: "1A9E6E") : Color(hex: "8D7694"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18).mlCard()
    }
}
