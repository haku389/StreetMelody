import SwiftUI

// ─────────────────────────────────────────────────────────────
//  フレンドを追加（StyleCare の FriendsManageScreen と同じ作り）
//
//  上から「自分の情報（招待）」「ユーザーIDで申請」「公開の設定」の順。
//  フレンドを増やしに来た画面なので、増やす手段を先に置く。
//  届いた申請はここではなく、フレンド一覧の「届いた申請」で見る。
// ─────────────────────────────────────────────────────────────

struct FriendAddView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var query = ""
    @State private var searching = false
    @State private var result: SupabaseClient.PublicProfile?
    @State private var notFound = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if vm.isGuestAccount { LoginRequiredCard().padding(.top, 4) }
                MLSectionTitle(text: "自分の情報").padding(.top, vm.isGuestAccount ? 0 : -10)
                myCard
                MLSectionTitle(text: "ユーザーIDで申請")
                searchCard
                MLSectionTitle(text: "公開の設定")
                MLMenuCard(icon: "eye", title: "プロフィールの公開範囲",
                           desc: "フレンドに見せる項目を選べます（表示名・ID・好きな曲は全員に公開）") {
                    vm.showProfileEdit = true
                }
            }
            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
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
                Text("フレンドを追加").font(.system(size: 15, weight: .black)).foregroundStyle(MLPalette.ink)
            }
        }
        .task { await vm.loadFriends() }
    }

    // MARK: 自分の情報（招待）

    private var myCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                UserAvatar(image: vm.avatarUIImage(), name: vm.profile.displayName ?? "", size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.profile.displayName ?? "名前未設定").font(.system(size: 15, weight: .black)).foregroundStyle(MLPalette.ink)
                    HStack(spacing: 6) {
                        Text(vm.myHandle.map { "@\($0)" } ?? "@----")
                            .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "A27BC8")).lineLimit(1)
                        CopyIdButton(handle: vm.myHandle, showsLabel: false)
                    }
                }
                Spacer()
            }

            if vm.myHandle == nil {
                // ID が無いと、相手はあなたを探せない
                Button { vm.showProfileEdit = true } label: {
                    Label("ユーザーIDを決めると、相手があなたを探せます", systemImage: "exclamationmark.circle")
                        .font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "C2410C"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).background(Color(hex: "FFF1E6"), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(MLPressButtonStyle())
            }

            HStack(spacing: 10) {
                inviteButton("QRを見せる", icon: "qrcode") { vm.navigate(to: .inviteCard) }
                inviteButton("近くの人", icon: "dot.radiowaves.left.and.right") { vm.navigate(to: .nearbyFriends) }
            }
            if let url = vm.myInviteURL {
                ShareLink(item: url, message: Text("StreetMelody でフレンドになろう！ ユーザーID：@\(vm.myHandle ?? "")")) {
                    Label("招待リンクを送る", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color(hex: "EEE0F2"), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(16).mlCard()
    }

    private func inviteButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .black))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(LinearGradient(colors: [Color(hex: "9670F0"), Color(hex: "A27BC8")], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .mlGlow()
        }
        .buttonStyle(MLPressButtonStyle())
        .disabled(vm.myHandle == nil)
        .opacity(vm.myHandle == nil ? 0.5 : 1)
    }

    // MARK: ユーザーIDで申請

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("@").font(.system(size: 15, weight: .black)).foregroundStyle(Color(hex: "B29ABC"))
                    TextField("相手のユーザーID", text: $query)
                        .font(.system(size: 15, weight: .bold))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focused)
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                }
                .padding(.horizontal, 12).padding(.vertical, 11)
                .background(Color(hex: "FFF4ED"), in: RoundedRectangle(cornerRadius: 12))
                Button { Task { await search() } } label: {
                    Group {
                        if searching { ProgressView().tint(.white) } else { Text("検索") }
                    }
                    .font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                    .frame(width: 64, height: 42)
                    .background(Color(hex: "A27BC8"), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(MLPressButtonStyle())
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
            }

            if let p = result {
                HStack(spacing: 12) {
                    UserAvatar(name: p.displayName ?? p.handle ?? "", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.displayName ?? "名前未設定").font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                        Text(p.handle.map { "@\($0)" } ?? "").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "8D7694"))
                    }
                    Spacer()
                    FriendRelationButton(userId: p.userId, compact: true)
                }
                .padding(12)
                .background(Color(hex: "F8F5FF"), in: RoundedRectangle(cornerRadius: 14))
            } else if notFound {
                Text("見つかりませんでした。IDをもう一度確かめてください。")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "8D7694"))
            }
            Text("申請は相手が承認するまでフレンドになりません。")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "B29ABC"))
        }
        .padding(16).mlCard()
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        focused = false
        searching = true; notFound = false
        result = await vm.findUser(handle: q)
        notFound = result == nil
        searching = false
    }
}

// MARK: - 関係に応じて押すものを変えるボタン（StyleCare の InviteCardSheet と同じ考え）
//
//  まだ何も無い → 「申請を送る」
//  相手から申請が来ている → 「承認する」（その場でフレンド）
//  こちらから申請済み → 押せない「申請中」
//  すでにフレンド → 「フレンド」
//  自分 → 何もしない
//  **申請は自動では送らない。** 押した覚えのない申請が届くのは、送る側にも受ける側にも良くない。

struct FriendRelationButton: View {
    @EnvironmentObject var vm: AppViewModel
    let userId: String
    var compact: Bool = false
    @State private var busy = false

    var body: some View {
        let rel = vm.relation(to: userId)
        let (title, filled, enabled): (String, Bool, Bool) = {
            if vm.isMe(userId) { return ("あなたです", false, false) }
            switch rel {
            case .none:      return (compact ? "申請" : "フレンド申請を送る", true, true)
            case .incoming?: return (compact ? "承認" : "申請を承認する", true, true)
            case .outgoing?: return ("申請中", false, false)
            case .friend?:   return ("フレンド", false, false)
            }
        }()
        Button {
            busy = true
            Task {
                if rel == .incoming { await vm.acceptFriend(userId) } else { await vm.sendFriendRequest(to: userId) }
                busy = false
            }
        } label: {
            Group {
                if busy { ProgressView().tint(filled ? .white : Color(hex: "A27BC8")) } else { Text(title) }
            }
            .font(.system(size: compact ? 12 : 15, weight: .black))
            .foregroundStyle(filled ? .white : Color(hex: "8D7694"))
            .frame(maxWidth: compact ? nil : .infinity)
            .padding(.horizontal, compact ? 14 : 0).padding(.vertical, compact ? 8 : 14)
            .background(filled ? Color(hex: "A27BC8") : Color(hex: "EEE0F2"), in: Capsule())
        }
        .buttonStyle(MLPressButtonStyle())
        .disabled(!enabled || busy)
    }
}
