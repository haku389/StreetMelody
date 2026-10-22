import SwiftUI

/// ログイン / 新規登録（共通アカウント）。
///
/// StyleCare などエコシステムのアプリと同じアカウント。ここで登録すると他のアプリでも使え、
/// 他のアプリで作ったアカウントでここにもログインできる。
/// 匿名ログイン（ゲストの格上げ）はやめた。ログインしていないあいだは端末の中だけで動き、
/// ログインすると端末の進行がアカウントへ上がる。
/// ログイン方法は、共通アカウントのプロジェクトで有効なものだけを押せるようにする
/// （メール・Google・Spotify。Apple は有料の開発者登録が要るので今は無い）。
struct AccountLinkView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable { case login = "ログイン", signup = "新規登録" }
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var notice: String?
    @State private var working: String?   // 実行中のボタン: "email" / "google" / "spotify"
    @State private var providers: Set<String> = ["email", "google"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GlassSegment(items: Mode.allCases, selection: $mode) { $0.rawValue }

                    Label("StyleCare と同じアカウント（共通アカウント）で使えます", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "A27BC8"))
                    Text(mode == .login
                         ? "ログインすると、この端末の進行がアカウントに保存され、機種変更や再インストール後も戻せます。"
                         : "メールアドレスとパスワードで登録します。確認メールのリンクを押したあと、ログインしてください。")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color(hex: "8D7694"))

                    VStack(spacing: 10) {
                        TextField("メールアドレス", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color(hex: "FFF4ED"), in: RoundedRectangle(cornerRadius: 12))
                        SecureField("パスワード（6文字以上）", text: $password)
                            .textContentType(mode == .login ? .password : .newPassword)
                            .padding(12)
                            .background(Color(hex: "FFF4ED"), in: RoundedRectangle(cornerRadius: 12))
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
                        Rectangle().fill(Color(hex: "EADCE7")).frame(height: 1)
                        Text("または").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "B29ABC"))
                        Rectangle().fill(Color(hex: "EADCE7")).frame(height: 1)
                    }

                    providerButton("spotify", title: "Spotify で続ける",
                                   fg: .white, bg: Color(hex: "1DB954"), border: Color(hex: "1DB954")) {
                        await vm.signInWithSpotify(link: false)
                    }
                    providerButton("google", title: "Google で続ける",
                                   fg: Color(hex: "1c1c22"), bg: .white, border: Color(hex: "E5E7EB")) {
                        await vm.signInWithGoogle(link: false)
                    }
                    if !providers.contains("spotify") {
                        Text("Spotify でのログインは準備中です（共通アカウントの設定待ち）")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "B29ABC"))
                    }

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
            .task { providers = await SupabaseClient.shared.enabledProviders() }
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

    /// 音楽サービスなどのログインボタン。プロジェクトで無効なものは押せない。
    private func providerButton(_ id: String, title: String, fg: Color, bg: Color, border: Color,
                                action: @escaping () async -> String?) -> some View {
        let loading = working == id
        let enabled = providers.contains(id)
        return Button {
            error = nil; notice = nil; working = id
            Task {
                let err = await action()
                working = nil
                if let err { error = err } else { dismiss() }
            }
        } label: {
            HStack(spacing: 10) {
                if loading {
                    ProgressView().tint(fg)
                } else if id == "google" {
                    // StyleCare のログイン画面と同じ、白地に公式の G だけ
                    Image("google_g").resizable().scaledToFit().frame(width: 20, height: 20)
                } else {
                    LoginMethodIcon(method: id, size: 22)
                }
                Text(loading ? "接続中…" : title)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(fg)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border))
            .mlShadow(.low)
        }
        .disabled(working != nil || !enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}
