import SwiftUI

// ─────────────────────────────────────────────────────────────
//  フレンドの一覧（StyleCare の FriendsListScreen と同じ作り）
//
//  ここは一覧に徹する。追加は右上の「＋」の向こう側（フレンドを追加）。
//  「フレンド」と「届いた申請」を小タブで分ける ―― 誰から来たかは、
//  誰とフレンドかの隣で見るほうが探しやすい。
//  行は1人1枚のカードにしない（10人並べただけで縦に伸び、探すためのスクロールが増える）。
//  各行の「…」から、その人に対してできること（ベスト指定・解除）を出す。
// ─────────────────────────────────────────────────────────────

struct FriendsView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var tab: FriendTab
    @State private var removing: SupabaseClient.FriendUser?

    init(initialTab: FriendTab) { _tab = State(initialValue: initialTab) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassSegment(items: FriendTab.allCases, selection: $tab) { t in
                    let n = t == .list ? vm.friendsOnly.count : vm.incomingRequests.count
                    return n > 0 ? "\(t.rawValue) \(n)" : t.rawValue
                }
                if vm.isGuestAccount { LoginRequiredCard() }
                else if tab == .list { friendList } else { requestList }
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
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(Color(hex: "7248E0"))
                }
            }
            ToolbarItem(placement: .principal) {
                Text("フレンド").font(.system(size: 15, weight: .black)).foregroundStyle(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { vm.navigate(to: .friendAdd) } label: {
                    Image(systemName: "person.badge.plus").font(.system(size: 16, weight: .bold)).foregroundStyle(Color(hex: "7248E0"))
                }
                .accessibilityLabel("フレンドを追加")
            }
        }
        .task { await vm.loadFriends() }
        .refreshable { await vm.loadFriends() }
        .confirmationDialog("フレンドを解除しますか？", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible, presenting: removing) { u in
            Button("\(u.name) とのフレンドを解除", role: .destructive) {
                Task { await vm.removeFriendLink(u.userId, toast: "フレンドを解除しました") }
            }
        } message: { _ in
            Text("相手の一覧からもあなたが消えます。もう一度フレンドになるには、申請と承認がまた要ります。")
        }
    }

    // MARK: フレンド

    @ViewBuilder
    private var friendList: some View {
        // ベストを先に並べる
        let list = vm.friendsOnly.sorted { ($0.isBest ? 0 : 1, $0.name) < ($1.isBest ? 0 : 1, $1.name) }
        if list.isEmpty {
            emptyCard(icon: "person.2", title: "まだフレンドがいません",
                      desc: "ユーザーID・QR・近くの人から申請して、相手が承認するとフレンドになります。",
                      action: ("フレンドを追加", { vm.navigate(to: .friendAdd) }))
        } else {
            rowsCard(list) { u in
                Menu {
                    Button { Task { await vm.toggleBestFriend(u.userId, isBest: !u.isBest) } } label: {
                        Label(u.isBest ? "ベストフレンドから外す" : "ベストフレンドに指定", systemImage: u.isBest ? "star.slash" : "star")
                    }
                    Button(role: .destructive) { removing = u } label: {
                        Label("フレンドを解除", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold)).foregroundStyle(Color(hex: "7B6F8A"))
                        .frame(width: 36, height: 36).contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: 届いた申請（＋送った申請）

    @ViewBuilder
    private var requestList: some View {
        if vm.incomingRequests.isEmpty {
            emptyCard(icon: "tray", title: "届いた申請はありません",
                      desc: "申請が届くとここに並びます。承認するとフレンドになります。", action: nil)
        } else {
            rowsCard(vm.incomingRequests) { u in
                HStack(spacing: 6) {
                    smallButton("承認", filled: true) { Task { await vm.acceptFriend(u.userId) } }
                    smallButton("削除", filled: false) { Task { await vm.removeFriendLink(u.userId, toast: "申請を削除しました") } }
                }
            }
        }
        if !vm.outgoingRequests.isEmpty {
            Text("送った申請").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "7B6F8A")).padding(.top, 6)
            rowsCard(vm.outgoingRequests) { u in
                smallButton("取り消す", filled: false) { Task { await vm.removeFriendLink(u.userId, toast: "申請を取り消しました") } }
            }
        }
    }

    // MARK: 部品

    private func rowsCard<Trailing: View>(_ users: [SupabaseClient.FriendUser],
                                          @ViewBuilder trailing: @escaping (SupabaseClient.FriendUser) -> Trailing) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(users.enumerated()), id: \.element.id) { i, u in
                HStack(spacing: 12) {
                    UserAvatar(name: u.displayName ?? u.handle ?? "", size: 42, best: u.isBest)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(u.displayName ?? "名前未設定").font(.system(size: 14, weight: .black)).foregroundStyle(.primary).lineLimit(1)
                        Text(u.handle.map { "@\($0)" } ?? "IDなし").font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "7B6F8A")).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    trailing(u)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                if i < users.count - 1 { Divider().padding(.leading, 68) }
            }
        }
        .padding(.vertical, 4)
        .mlCard()
    }

    private func smallButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .black))
                .foregroundStyle(filled ? .white : Color(hex: "7B6F8A"))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(filled ? Color(hex: "7248E0") : Color(hex: "EDE8FF"), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func emptyCard(icon: String, title: String, desc: String, action: (String, () -> Void)?) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 26, weight: .semibold)).foregroundStyle(Color(hex: "B8ACD6"))
            Text(title).font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
            Text(desc).font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "7B6F8A")).multilineTextAlignment(.center)
            if let action {
                Button(action: action.1) {
                    Text(action.0).font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Color(hex: "7248E0"), in: Capsule())
                }
                .buttonStyle(.plain).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 28).padding(.horizontal, 20)
        .mlCard()
    }
}

// MARK: - ログインしていないとき（フレンドはアカウントが要る）

struct LoginRequiredCard: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showLogin = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.exclamationmark").font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(hex: "B8ACD6"))
            Text("フレンドにはログインが要ります").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
            Text("StyleCare と同じアカウント（共通アカウント）でログインすると、申請・承認ができます。")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "7B6F8A")).multilineTextAlignment(.center)
            Button { showLogin = true } label: {
                Text("ログイン / 新規登録").font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Color(hex: "7248E0"), in: Capsule())
            }
            .buttonStyle(.plain).padding(.top, 4)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 26).padding(.horizontal, 20)
        .mlCard()
        .sheet(isPresented: $showLogin) { AccountLinkView().environmentObject(vm) }
    }
}
