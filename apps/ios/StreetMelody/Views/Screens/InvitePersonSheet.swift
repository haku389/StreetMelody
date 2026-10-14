import SwiftUI

// ─────────────────────────────────────────────────────────────
//  招待リンク・QR から開いたとき（StyleCare の InviteCardSheet と同じ考え）
//
//  誰からの招待なのかを先に見せて、1回押せば申請が届く形にする。
//  **申請は自動では送らない。** 押した覚えのない申請が届くのは良くない。
//  フレンドになる前に見せるのは、名前・ID・アイコンだけ。
// ─────────────────────────────────────────────────────────────

extension SupabaseClient.PublicProfile: Identifiable { var id: String { userId } }

struct InvitePersonSheet: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let person: SupabaseClient.PublicProfile

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color(hex: "E0D8F7")).frame(width: 40, height: 5).padding(.top, 10)
            UserAvatar(name: person.displayName ?? person.handle ?? "", size: 76)
                .padding(.top, 8)
            VStack(spacing: 4) {
                Text(person.displayName ?? "名前未設定").font(.system(size: 20, weight: .black)).foregroundStyle(.primary)
                Text(person.handle.map { "@\($0)" } ?? "").font(.system(size: 13, weight: .heavy)).foregroundStyle(Color(hex: "7248E0"))
            }
            Text(caption).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "7B6F8A"))
                .multilineTextAlignment(.center).padding(.horizontal, 24)

            FriendRelationButton(userId: person.userId)
                .padding(.horizontal, 24)

            if vm.relation(to: person.userId) == .friend {
                Button("フレンドの一覧を見る") {
                    dismiss()
                    vm.navigate(to: .friends(.list))
                }
                .font(.system(size: 13, weight: .black)).foregroundStyle(Color(hex: "7248E0"))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "FBF9FF").ignoresSafeArea())
        .presentationDetents([.height(380)])
        .task { await vm.loadFriends() }
    }

    private var caption: String {
        if vm.isMe(person.userId) { return "あなたの招待リンクです" }
        switch vm.relation(to: person.userId) {
        case .none:      return "申請して、相手が承認するとフレンドになります"
        case .incoming?: return "この人から申請が届いています"
        case .outgoing?: return "申請済みです。相手の承認を待っています"
        case .friend?:   return "すでにフレンドです"
        }
    }
}
