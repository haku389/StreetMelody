import SwiftUI
import UIKit

// つながり一覧（フレンド＝相互フォロー / フォロー中 / フォロワー）。
// マイページの件数タップ／「フレンドを追加」から開く。
struct SocialListView: View {
    let initialTab: SocialTab
    @EnvironmentObject var vm: AppViewModel
    @State private var tab: SocialTab
    @State private var showAddFriend = false
    @State private var addCodeText = ""
    @State private var addCodeNick = ""

    init(initialTab: SocialTab) {
        self.initialTab = initialTab
        _tab = State(initialValue: initialTab)
    }

    private var friends:   [SupabaseClient.SocialUser] { vm.social.filter { $0.isFriend } }
    private var following: [SupabaseClient.SocialUser] { vm.social.filter { $0.following } }
    private var followers: [SupabaseClient.SocialUser] { vm.social.filter { $0.followedBy } }
    private var current: [SupabaseClient.SocialUser] {
        switch tab { case .friends: return friends; case .following: return following; case .followers: return followers }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                countsBar
                addFriendCard
                if !vm.nearbyUsers.isEmpty { nearbyCard }
                segmented
                listCard
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .mlNavBarBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(Color(hex: "7248E0"))
                }
            }
            ToolbarItem(placement: .principal) {
                Text("つながり").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
            }
        }
        .task { await vm.loadSocialGraph() }
        .sheet(isPresented: $showAddFriend) { addFriendSheet }
    }

    // MARK: 件数バー

    private var countsBar: some View {
        HStack(spacing: 0) {
            countItem(friends.count, .friends)
            Divider().frame(height: 26)
            countItem(following.count, .following)
            Divider().frame(height: 26)
            countItem(followers.count, .followers)
        }
        .padding(.vertical, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "EDE8FF")))
    }

    private func countItem(_ n: Int, _ t: SocialTab) -> some View {
        Button { tab = t } label: {
            VStack(spacing: 3) {
                Text("\(n)").font(.system(size: 19, weight: .black)).foregroundStyle(tab == t ? Color(hex: "7248E0") : .primary)
                Text(t.rawValue).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: 自分のコード＋追加

    private var addFriendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("自分のコード").font(.system(size: 12, weight: .black)).foregroundStyle(.primary)
                Spacer()
                Button("フレンドを追加") { addCodeText = ""; addCodeNick = ""; showAddFriend = true }
                    .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color(hex: "7248E0"), in: RoundedRectangle(cornerRadius: 10))
            }
            HStack(spacing: 8) {
                Text(vm.friendCode ?? "—")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.primary).lineLimit(1).truncationMode(.middle)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "F5F0FF"), in: RoundedRectangle(cornerRadius: 10))
                Button("コピー") {
                    if let c = vm.friendCode { UIPasteboard.general.string = c; vm.showToast("コードをコピーしました") }
                }
                .font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "7248E0"))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16).mlCard()
    }

    // MARK: すれちがった人

    private var nearbyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🤝 すれちがった人").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "7248E0"))
            ForEach(vm.nearbyUsers) { u in
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: "EDE8FF")).frame(width: 30, height: 30).overlay(Text("🎵").font(.system(size: 13)))
                    Text("ユーザー(\(u.userId.suffix(4)))").font(.system(size: 12, weight: .black)).foregroundStyle(.primary)
                    Spacer()
                    Button("フォロー") { Task { await vm.followNearby(u.userId, nickname: "すれちがい") } }
                        .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color(hex: "7248E0"), in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16).mlCard()
    }

    // MARK: セグメント

    private var segmented: some View {
        GlassSegment(items: SocialTab.allCases, selection: $tab) { $0.rawValue }
    }

    // MARK: リスト

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if tab == .friends {
                let bests = friends.filter { $0.isBest }
                if !bests.isEmpty {
                    Text("⭐ ベストフレンド \(bests.count)").font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "E0A020"))
                        .padding(.bottom, 6)
                    ForEach(bests) { u in socialRow(u); Divider().background(Color(hex: "E0D8F7")) }
                    Text("フレンド").font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "7B6F8A"))
                        .padding(.top, 8).padding(.bottom, 2)
                }
            }
            if current.isEmpty {
                Text(emptyText).font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            } else {
                ForEach(Array(current.enumerated()), id: \.element.id) { i, u in
                    socialRow(u)
                    if i < current.count - 1 { Divider().background(Color(hex: "E0D8F7")) }
                }
            }
        }
        .padding(16).mlCard()
    }

    private var emptyText: String {
        switch tab {
        case .friends:   return "まだフレンドがいません。相互フォローでフレンドになります。"
        case .following: return "まだ誰もフォローしていません。コードやすれちがいでフォローしましょう。"
        case .followers: return "まだフォロワーがいません。"
        }
    }

    private func socialRow(_ u: SupabaseClient.SocialUser) -> some View {
        HStack(spacing: 8) {
            Circle().fill(u.isBest ? Color(hex: "FFF3D6") : Color(hex: "EDE8FF")).frame(width: 32, height: 32)
                .overlay(Text(u.isBest ? "⭐" : "🎵").font(.system(size: 14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(u.nickname ?? "ユーザー(\(u.userId.suffix(4)))")
                    .font(.system(size: 12, weight: .black)).foregroundStyle(.primary).lineLimit(1)
                HStack(spacing: 5) {
                    if u.isFriend {
                        Text("フレンド").font(.system(size: 8, weight: .black)).foregroundStyle(Color(hex: "1A9E6E"))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color(hex: "1A9E6E").opacity(0.12), in: Capsule())
                    } else if u.following {
                        Text("フォロー中").font(.system(size: 8, weight: .black)).foregroundStyle(Color(hex: "7B6F8A"))
                    } else if u.followedBy {
                        Text("フォロワー").font(.system(size: 8, weight: .black)).foregroundStyle(Color(hex: "7B6F8A"))
                    }
                    if u.isBest { Text("★ベスト").font(.system(size: 8, weight: .black)).foregroundStyle(Color(hex: "E0A020")) }
                }
            }
            Spacer()
            if u.isFriend {
                Button { Task { await vm.toggleBestFriend(u.userId, isBest: !u.isBest) } } label: {
                    Image(systemName: u.isBest ? "star.fill" : "star").font(.system(size: 14)).foregroundStyle(Color(hex: "E0A020"))
                }
            }
            if u.following {
                Button("解除") { Task { await vm.unfollow(u.userId) } }
                    .font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: "7B6F8A"))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Button("フォロー") { Task { await vm.followByCode(code: u.userId, nickname: u.nickname ?? "") } }
                    .font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color(hex: "7248E0"), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.vertical, 8)
    }

    private var addFriendSheet: some View {
        NavigationStack {
            Form {
                Section("フォローするコード") {
                    TextField("相手のコード（36文字）", text: $addCodeText)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("ニックネーム（任意）", text: $addCodeNick)
                }
                Section {
                    Button("フォローする") {
                        let code = addCodeText.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task { await vm.followByCode(code: code, nickname: addCodeNick) }
                        showAddFriend = false
                    }
                    .disabled(addCodeText.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
                }
            }
            .navigationTitle("フレンドを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { showAddFriend = false } } }
        }
        .presentationDetents([.medium])
    }
}
