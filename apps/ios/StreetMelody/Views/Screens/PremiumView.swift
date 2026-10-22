import SwiftUI

struct PremiumView: View {
    @EnvironmentObject var vm: AppViewModel

    private let benefits = [
        ("🚫", "広告非表示",       "ヒント・答えの解放時に広告視聴が不要になります"),
        ("🎵", "推し曲5曲",       "推し曲の設定上限が3曲 → 5曲に増えます"),
        ("📍", "エリアランキング",  "離れたエリアのランキングも閲覧できます"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                navHeader
                heroCard
                benefitsList
                if vm.premium { cancelButton } else { purchaseButton }
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
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "A27BC8"))
                }
            }
        }
    }

    private var navHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("プレミアムプラン").font(.system(size: 20, weight: .black)).foregroundStyle(MLPalette.ink)
                Text(vm.premium ? "⭐ 加入中" : "もっと音楽でつながる")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(vm.premium ? Color(hex: "b8860b") : Color(hex: "8D7694"))
            }
            Spacer()
        }
        .padding(.bottom, 18)
    }

    private var heroCard: some View {
        VStack(spacing: 12) {
            Text("⭐").font(.system(size: 36))
            Text("StreetMelody プレミアム").font(.system(size: 16, weight: .black)).foregroundStyle(MLPalette.ink)
            Text("¥480 / 月").font(.system(size: 22, weight: .black)).foregroundStyle(Color(hex: "b8860b"))
            Text("いつでもキャンセル可能").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(colors: [Color(hex: "ffd700").opacity(0.1), Color(hex: "A27BC8").opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: "ffd700").opacity(0.45)))
        .padding(.bottom, 16)
    }

    private var benefitsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { i, b in
                HStack(spacing: 12) {
                    Text(b.0).font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.1).font(.system(size: 13, weight: .black)).foregroundStyle(MLPalette.ink)
                        Text(b.2).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                    }
                }
                .padding(.vertical, 14)
                if i < benefits.count - 1 { Divider().background(Color(hex: "EADCE7")) }
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 16)
    }

    private var purchaseButton: some View {
        Button { vm.buyPremium() } label: {
            Text("プレミアムに加入する（¥480/月）")
                .font(.system(size: 15, weight: .black)).foregroundStyle(Color(hex: "3a2400"))
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [Color(hex: "ffe28a"), Color(hex: "ffc85b")], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 20)
                )
        }
    }

    private var cancelButton: some View {
        Button {
            vm.cancelPremium()
        } label: {
            Text("解約する")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Color(hex: "8D7694"))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color(hex: "EEE0F2"), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "EADCE7")))
        }
    }
}
