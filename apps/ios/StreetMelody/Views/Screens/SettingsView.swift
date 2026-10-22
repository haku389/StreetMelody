import SwiftUI

// ─────────────────────────────────────────────────────────────
//  設定（StyleCare の MyPageScreen の設定シートと同じ並び）
//
//  マイページの歯車から、下から出るシートで開く。
//   アカウント     … ログイン中のメール・ログイン方法（メール／Google／Spotify。「追加」で足せる）
//   アプリについて … 利用規約・プライバシーポリシー・ログアウト（赤。確かめてから）
//  名前・ID・ひとこと・写真は、ここではなくマイページのプロフィールのカードから直す
//  （StyleCare も設定には置いていない）。
//
//  アカウントの削除は StyleCare には有るが、ここにはまだ無い。共通アカウントの削除は
//  StyleCare の Worker（/api/account/delete）が受け持ち、StyleCare 専用の鍵が要るため。
// ─────────────────────────────────────────────────────────────

struct SettingsView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAccountSheet = false
    @State private var linking: String?   // 足している途中のログイン方法
    @State private var confirmLogout = false

    private let danger = Color(hex: "E5484D")

    var body: some View {
        ZStack {
            MLBackground()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        MLSectionTitle(text: "アカウント")
                        accountCard
                        MLSectionTitle(text: "アプリについて")
                        MLMenuCard(icon: "doc.text.fill", tint: Color(hex: "8D7694"), title: "利用規約") {
                            vm.showToast("利用規約は準備中です")
                        }
                        MLMenuCard(icon: "hand.raised.fill", tint: Color(hex: "8D7694"), title: "プライバシーポリシー") {
                            vm.showToast("プライバシーポリシーは準備中です")
                        }
                        if !vm.isGuestAccount {
                            MLMenuCard(icon: "rectangle.portrait.and.arrow.right", tint: danger,
                                       title: "ログアウト", titleColor: danger) {
                                confirmLogout = true
                            }
                        }
                        Text("StreetMelody \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "B29ABC"))
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            // シートの下にあるタブの通知は見えないので、ここでも出す
            if let toast = vm.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Color(hex: "49335F").opacity(0.95), in: Capsule())
                        .shadow(radius: 8, y: 4)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: toast)
            }
        }
        .sheet(isPresented: $showAccountSheet) { AccountLinkView().environmentObject(vm) }
        .alert("ログアウトしますか？", isPresented: $confirmLogout) {
            Button("ログアウト", role: .destructive) {
                Task {
                    await vm.signOutAccount()
                    dismiss()
                }
            }
            Button("やめる", role: .cancel) {}
        }
    }

    /// 左に同じ幅の空き、真ん中に「設定」、右に閉じる（StyleCare と同じ）
    private var header: some View {
        HStack {
            Color.clear.frame(width: 34, height: 34)
            Spacer()
            Text("設定").font(.system(size: 16, weight: .black)).foregroundStyle(MLPalette.ink)
            Spacer()
            GlassIconButton(systemName: "xmark", size: 34, accessibilityLabel: "閉じる") { dismiss() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - アカウント

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill((vm.isGuestAccount ? Color(hex: "8D7694") : Color(hex: "1A9E6E")).opacity(0.13))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: vm.isGuestAccount ? "person.fill.questionmark" : "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(vm.isGuestAccount ? Color(hex: "8D7694") : Color(hex: "1A9E6E")))
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.isGuestAccount ? "ログインしていません" : "ログイン中")
                        .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                    Text(vm.isGuestAccount ? "端末の中だけで動いています · ログインでフレンド・機種変更に対応"
                                           : (vm.accountEmail ?? "共通アカウント"))
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "8D7694"))
                }
            }
            if vm.isGuestAccount {
                Button { showAccountSheet = true } label: {
                    Text("ログイン / 新規登録").buttonLabel(.primary)
                }
            } else {
                loginMethods
            }
        }
        .padding(16).mlCard()
    }

    /// ログイン方法（メール・Google・Spotify）。足りないものは「追加」で、今のアカウントに足せる
    private var loginMethods: some View {
        let rows: [(id: String, name: String)] = [("email", "メール"), ("google", "Google"), ("spotify", "Spotify")]
        return VStack(alignment: .leading, spacing: 0) {
            Text("ログイン方法").font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "8D7694"))
                .padding(.bottom, 6)
            ForEach(rows, id: \.id) { r in
                let linked = vm.linkedProviders.contains(r.id)
                let canAdd = !linked && r.id != "email" && vm.availableProviders.contains(r.id)
                if linked || canAdd {
                    HStack(spacing: 10) {
                        LoginMethodIcon(method: r.id, size: 24)
                        Text(r.name).font(.system(size: 13, weight: .black)).foregroundStyle(MLPalette.ink)
                        Spacer()
                        if linked {
                            Label("使えます", systemImage: "checkmark").font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color(hex: "1A9E6E"))
                        } else {
                            Button {
                                linking = r.id
                                Task {
                                    if let err = await vm.linkLoginMethod(r.id) { vm.showToast(err) }
                                    linking = nil
                                }
                            } label: {
                                Group {
                                    if linking == r.id { ProgressView().tint(.white) } else { Text("追加") }
                                }
                                .font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                                .frame(minWidth: 52).padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color(hex: "A27BC8"), in: Capsule())
                                .mlGlow()
                            }
                            .buttonStyle(MLPressButtonStyle())
                            .disabled(linking != nil)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            Text("足しても名前・ID・進行はそのまま。どの方法でも同じアカウントに入れます。")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "B29ABC"))
                .padding(.top, 4)
        }
        .padding(12)
        .mlInset(radius: 16)
        .task(id: vm.isGuestAccount) { await vm.loadLoginMethods() }
    }
}
