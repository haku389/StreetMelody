import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                navHeader
                if vm.friends.isEmpty {
                    emptyState
                } else {
                    friendsList
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .mlNavBarBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "7248E0"))
                }
            }
        }
    }

    private var navHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("フレンド").font(.system(size: 20, weight: .black)).foregroundStyle(.primary)
                Text("\(vm.friends.count)人とつながっています")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            Spacer()
        }
        .padding(.bottom, 18)
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Text("🎵")
            VStack(alignment: .leading, spacing: 2) {
                Text("まだフレンドがいません").font(.system(size: 12, weight: .black)).foregroundStyle(.primary)
                Text("すれちがいでピースを交換するとフレンドになれます")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
        }
        .padding(14).mlCard()
    }

    private var friendsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.friends.sorted { $0.addedAt > $1.addedAt }.enumerated()), id: \.element.id) { i, friend in
                Button {
                    vm.navigate(to: .friendDetail(userId: friend.userId))
                } label: {
                    HStack(spacing: 12) {
                        Circle().fill(Color(hex: "7248E0")).frame(width: 48, height: 48)
                            .overlay(Text("🎵").font(.system(size: 18)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(friend.userName)
                                .font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                            Text("📍 \(friend.locationLabel) · 交換\(friend.exchangeCount)回")
                                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("交換\(friend.exchangeCount)回")
                                .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12)).foregroundStyle(Color(hex: "B8ACD6"))
                        }
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                if i < vm.friends.count - 1 {
                    Divider().background(Color(hex: "E0D8F7"))
                }
            }
        }
        .padding(14).mlCard()
    }
}
