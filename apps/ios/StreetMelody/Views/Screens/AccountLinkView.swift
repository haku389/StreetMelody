import SwiftUI

/// ログイン / 新規登録（共通アカウント）。
///
/// StyleCare などエコシステムのアプリと同じアカウント。ここで登録すると他のアプリでも使え、
/// 他のアプリで作ったアカウントでここにもログインできる。
/// 匿名ログイン（ゲストの格上げ）はやめた。ログインしていないあいだは端末の中だけで動き、
/// ログインすると端末の進行がアカウントへ上がる。
/// 使えるのはメールと Google（共通アカウントのプロジェクトで有効なもの）。
struct AccountLinkView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable { case login = "ログイン", signup = "新規登録" }
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var notice: String?
    @State private var working: String?   // 実行中のボタン: "email" / "google"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GlassSegment(items: Mode.allCases, selection: $mode) { $0.rawValue }

                    Label("StyleCare と同じアカウント（共通アカウント）で使えます", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "7248E0"))
                    Text(mode == .login
                         ? "ログインすると、この端末の進行がアカウントに保存され、機種変更や再インストール後も戻せます。"
                         : "メールアドレスとパスワードで登録します。確認メールのリンクを押したあと、ログインしてください。")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color(hex: "7B6F8A"))

                    VStack(spacing: 10) {
                        TextField("メールアドレス", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color(hex: "F5F0FF"), in: RoundedRectangle(cornerRadius: 12))
                        SecureField("パスワード（6文字以上）", text: $password)
                            .textContentType(mode == .login ? .password : .newPassword)
                            .padding(12)
                            .background(Color(hex: "F5F0FF"), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if let error {
                        Text(error).font(.system(size: 11, weight: .heavy)).foregroundStyle(.red)
                    }
                    if let notice {
                        Label(notice, systemImage: "envelope.badge")
                            .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "1A9E6E"))
                    }

                    Button { submit() } label: {
                        Text(working == "email" ? "処理中…" : mode.rawValue).buttonLabel(.primary)
                    }
                    .disabled(working != nil || email.isEmpty || password.count < 6)

                    HStack {
                        Rectangle().fill(Color(hex: "E0D8F7")).frame(height: 1)
                        Text("または").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "B8ACD6"))
                        Rectangle().fill(Color(hex: "E0D8F7")).frame(height: 1)
                    }

                    googleButton

                    Spacer(minLength: 8)
                }
                .padding(20)
            }
            .background(Color(hex: "FFFFFF").ignoresSafeArea())
            .navigationTitle("アカウント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onChange(of: mode) { _ in error = nil; notice = nil }
        }
    }

    private func submit() {
        error = nil; notice = nil
        working = "email"
        Task {
            if mode == .login {
                let result = await vm.signInAccount(email: email, password: password)
                working = nil
                if let result { error = result } else { dismiss() }
            } else {
                let result = await vm.signUpAccount(email: email, password: password)
                working = nil
                switch result {
                case .signedIn:          dismiss()
                case .needsConfirmation: notice = "確認メールを送りました。メールのリンクを押してから「ログイン」してください。"
                                         mode = .login
                case .failed(let m):     error = m
                }
            }
        }
    }

    private var googleButton: some View {
        let loading = working == "google"
        return Button {
            error = nil; notice = nil; working = "google"
            Task {
                let err = await vm.signInWithGoogle(link: false)
                working = nil
                if let err { error = err } else { dismiss() }
            }
        } label: {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(Color(hex: "1c1c22")) }
                Text(loading ? "接続中…" : "Google で続ける")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color(hex: "1c1c22"))
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "E0D8F7")))
        }
        .disabled(working != nil)
    }
}
