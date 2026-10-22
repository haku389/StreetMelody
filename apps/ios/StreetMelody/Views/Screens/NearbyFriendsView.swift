import SwiftUI

// ─────────────────────────────────────────────────────────────
//  近くの人（StyleCare の NearbyInviteScreen と同じ考え）
//
//  QR が主で、こちらは同じ場所にいるときの近道。お互いがアプリを開いていると
//  名前が並ぶ。何人かをまとめて誘うときは、こちらのほうが速い。
//  見つけるところまでが Bluetooth で、申請はいつもと同じ道を通る。
//  **相手が承認するまでフレンドにはならない**ので、近くにいるだけで関係はできない。
// ─────────────────────────────────────────────────────────────

struct NearbyFriendsView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: "A27BC8"))
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                    Text("お互いに StreetMelody を開いていると、近くの人がここに並びます")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "8D7694"))
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).mlCard()

                if vm.nearbyUsers.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView().tint(Color(hex: "A27BC8"))
                        Text("近くの人を探しています…").font(.system(size: 13, weight: .black)).foregroundStyle(MLPalette.ink)
                        Text("Bluetooth をオンにして、相手にもこの画面を開いてもらってください")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "8D7694"))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 28).mlCard()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(vm.nearbyUsers.enumerated()), id: \.element.id) { i, u in
                            let p = vm.nearbyNames[u.userId.lowercased()]
                            HStack(spacing: 12) {
                                UserAvatar(name: p?.displayName ?? p?.handle ?? "", size: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p?.displayName ?? "近くの人").font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                                    Text(p?.handle.map { "@\($0)" } ?? "名前を読み込み中…").font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color(hex: "8D7694"))
                                }
                                Spacer()
                                FriendRelationButton(userId: u.userId, compact: true)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            if i < vm.nearbyUsers.count - 1 { Divider().padding(.leading, 68) }
                        }
                    }
                    .padding(.vertical, 4).mlCard()
                }
                Text("申請は相手が承認するまでフレンドになりません。")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "B29ABC"))
            }
            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 112)
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
                Text("近くの人").font(.system(size: 15, weight: .black)).foregroundStyle(MLPalette.ink)
            }
        }
        .task {
            vm.startNearbyExchange()
            await vm.loadFriends()
            await vm.loadNearbyNames()
        }
    }
}
