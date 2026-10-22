import SwiftUI

/// ピース取得直後に表示する「フレンド申請カード」＋「次の出会いへ」導線（Web版相当）。
/// MysteryView / PuzzleView の末尾に配置する。
struct PostCollectSection: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        if vm.pendingFriendAdd != nil || vm.showNextEncounterPrompt {
            VStack(spacing: 12) {
                if let pf = vm.pendingFriendAdd {
                    friendCard(pf)
                }
                if vm.showNextEncounterPrompt {
                    nextEncounter()
                }
            }
            .padding(.top, 14)
        }
    }

    // MARK: - フレンド申請カード

    private func friendCard(_ pf: PendingFriend) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle().fill(Color(hex: "A27BC8")).frame(width: 40, height: 40)
                    .overlay(Text("🎵").font(.system(size: 16)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pf.userName) さんとメロディでつながりました")
                        .font(.system(size: 13, weight: .black)).foregroundStyle(MLPalette.ink)
                    Text("フレンドになって音楽をシェアしませんか？")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                }
            }
            HStack(spacing: 8) {
                Button { vm.confirmFriendAdd() } label: {
                    Text("フレンドに追加")
                        .font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color(hex: "A27BC8"), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(MLPressButtonStyle())
                Button { vm.dismissFriendPrompt() } label: {
                    Text("スキップ")
                        .font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "8D7694"))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color(hex: "EEE0F2"), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(MLPressButtonStyle())
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color(hex: "A27BC8").opacity(0.08), Color(hex: "1A9E6E").opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "A27BC8").opacity(0.3)))
    }

    // MARK: - 次の出会いへ

    @ViewBuilder
    private func nextEncounter() -> some View {
        if let enc = vm.nextAvailableEncounter,
           let idx = vm.encounters.firstIndex(where: { $0.id == enc.id }) {
            Button { vm.goToNextEncounter() } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(idx + 1)人目の出会いへ")
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(.white.opacity(0.85))
                        Text("\(enc.fromUserName) さん / \(enc.locationLabel)")
                            .font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                    }
                    Spacer()
                    Text("›").font(.system(size: 20, weight: .black)).foregroundStyle(.white)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(LinearGradient(colors: [Color(hex: "A27BC8"), Color(hex: "9670F0")],
                                           startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(MLPressButtonStyle())
        } else {
            VStack(spacing: 4) {
                Text("🎉 今日の出会いを全て確認しました")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                if let minRemaining = vm.encounters.map({ vm.cooldownRemaining(for: $0.id) }).min(),
                   minRemaining > 0 {
                    Text("次の出会いまであと \(vm.formatCooldown(minRemaining))")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "B29ABC"))
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
        }
    }
}
