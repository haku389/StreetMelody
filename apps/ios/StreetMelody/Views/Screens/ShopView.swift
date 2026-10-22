import SwiftUI

struct ShopView: View {
    @EnvironmentObject var vm: AppViewModel

    private var consumableItems: [ShopItem] {
        vm.shopItems.filter { $0.type != "decoration" }
    }
    private var decorationItems: [ShopItem] {
        vm.shopItems.filter { $0.type == "decoration" }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                navHeader
                coinBalance
                if !consumableItems.isEmpty { itemsSection }
                if !decorationItems.isEmpty { decorationsSection }
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
            Text("ショップ").font(.system(size: 20, weight: .black)).foregroundStyle(MLPalette.ink)
            Spacer()
        }
        .padding(.bottom, 14)
    }

    private var coinBalance: some View {
        HStack(spacing: 10) {
            Text("🪙")
            Text("所持メロディコイン")
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
            Spacer()
            Text("\(formatNumber(vm.coins)) コイン")
                .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
        }
        .padding(16).mlCard()
        .padding(.bottom, 16)
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("アイテム")
                .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                .padding(.bottom, 4)

            ForEach(consumableItems) { item in
                HStack(spacing: 12) {
                    Text(item.icon).font(.system(size: 28))
                        .frame(width: 50, height: 50)
                        .background(Color(hex: "EEE0F2"), in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name).font(.system(size: 13, weight: .black)).foregroundStyle(MLPalette.ink)
                        Text(item.description).font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color(hex: "8D7694")).lineLimit(2)
                    }

                    Spacer()

                    Button {
                        vm.buyShopItem(id: item.id)
                    } label: {
                        Text("🪙\(item.price)")
                            .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color(hex: "A27BC8"), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(14)
                .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "EADCE7")))
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 16)
    }

    private var decorationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("アバター装飾")
                .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                .padding(.bottom, 4)

            ForEach(decorationItems) { item in
                let isOwned = vm.ownedDecorations.contains(item.id)
                let isEquipped = vm.equippedDecoration == item.id

                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        Text(item.icon).font(.system(size: 28))
                            .frame(width: 50, height: 50)
                            .background(
                                isEquipped ? Color(hex: "A27BC8").opacity(0.15) : Color(hex: "EEE0F2"),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        if isEquipped {
                            Text("✓").font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .padding(2)
                                .background(Color(hex: "1A9E6E"), in: Circle())
                                .offset(x: 4, y: 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name).font(.system(size: 13, weight: .black)).foregroundStyle(MLPalette.ink)
                        Text(isOwned ? (isEquipped ? "装備中" : "所持済み") : item.description)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(isEquipped ? Color(hex: "1A9E6E") : Color(hex: "8D7694"))
                            .lineLimit(2)
                    }

                    Spacer()

                    if isOwned {
                        Button {
                            vm.equipDecoration(isEquipped ? nil : item.id)
                        } label: {
                            Text(isEquipped ? "はずす" : "装備")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(isEquipped ? Color(hex: "8D7694") : .white)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(
                                    isEquipped ? Color(hex: "EEE0F2") : Color(hex: "A27BC8"),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                        }
                    } else {
                        Button {
                            vm.buyShopItem(id: item.id)
                        } label: {
                            Text("🪙\(item.price)")
                                .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color(hex: "A27BC8"), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(14)
                .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(
                    isEquipped ? Color(hex: "A27BC8").opacity(0.4) : Color(hex: "EADCE7")))
            }
        }
        .padding(16).mlCard()
    }
}
