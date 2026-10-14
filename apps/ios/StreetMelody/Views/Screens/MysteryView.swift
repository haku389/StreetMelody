import SwiftUI

// 未解放メロディ（曲名当て）。著作権方針に沿った段階ヒント：
//  Lv0: アーティスト名表示 + 曲名?????? + 30秒試聴（広告なし）
//  Lv1: ジャンル/年代/雰囲気ヒント（広告可）
//  Lv2: 曲名の文字が数文字開く（広告可）
//  Lv3: Apple Music / Spotify で確認 + 曲名入力 + あとで聴く（広告なし）
// 広告・課金で答えを即解放する導線は廃止。
struct MysteryView: View {
    let trackId: String
    @EnvironmentObject var vm: AppViewModel
    @State private var showAdModal = false
    @State private var pendingHint: HintKind = .hint1
    @State private var showGuessAlert = false
    @State private var guessText = ""

    private var track: Track? { vm.track(for: trackId) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let t = track {
                    mysteryHero(track: t)
                    atmosphereCard(track: t)
                    actionBlock(track: t)
                    externalConfirm(track: t)
                    PostCollectSection()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color(hex: "F5F0FF"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "7248E0"))
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("未解放メロディ").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                    Text("ヒントを使ってこの曲の名前を当てよう！")
                        .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { vm.goBack() } label: {
                    Text("あとで").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
            }
        }
        .sheet(isPresented: $showAdModal) {
            AdConfirmModal(kind: pendingHint) {
                Task { await vm.applyHint(trackId: trackId, kind: pendingHint) }
            }
        }
        .alert("曲名を入力する", isPresented: $showGuessAlert) {
            TextField("曲名を入力してください", text: $guessText)
            Button("確認") {
                let _ = vm.guessTrack(trackId: trackId, answer: guessText)
                guessText = ""
            }
            Button("キャンセル", role: .cancel) { guessText = "" }
        } message: {
            Text("曲名を入力して正解すると解放されます")
        }
    }

    // MARK: - Mystery hero（独自生成カード＋アーティスト名＋伏せ字曲名）

    private func mysteryHero(track: Track) -> some View {
        VStack(spacing: 10) {
            ZStack {
                PuzzlePiecesView(ownedPieces: track.ownedPieces,
                                 color: track.color,
                                 seed: track.id,
                                 cornerRadius: 22,
                                 revealAll: true,
                                 blur: true)
                    .frame(maxWidth: min(300, UIScreen.main.bounds.width * 0.82))
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "7248E0").opacity(0.18))
                    .frame(width: 62, height: 62)
                    .overlay(Text("🔒").font(.system(size: 28)))
            }
            // アーティスト名は初期状態でも表示
            Text(track.displayArtist)
                .font(.system(size: 13, weight: .black)).foregroundStyle(Color(hex: "7248E0"))
            // 曲名は伏せ字（Lv2で一部開く）
            Text(track.maskedTitle(hintLevel: track.hintLevel))
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text("曲名を当てて解放しよう").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
        }
        .padding(.bottom, 16)
    }

    // MARK: - Lv1：ジャンル/年代/雰囲気

    private func atmosphereCard(track: Track) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ヒント①  曲の雰囲気").font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                Spacer()
                if track.hintLevel < 1 {
                    Text("広告").font(.system(size: 9, weight: .black)).foregroundStyle(Color(hex: "7B6F8A"))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(hex: "EDE8FF"), in: Capsule())
                }
            }
            if track.hintLevel >= 1 {
                HStack(spacing: 8) {
                    chip("🎼 \(track.genreHint)")
                    chip("📅 \(track.eraHint)")
                    chip("✨ \(track.moodHint)")
                }
            } else {
                Button { pendingHint = .hint1; showAdModal = true } label: {
                    Text("雰囲気のヒントを見る").buttonLabel(.secondary)
                }
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    private func chip(_ s: String) -> some View {
        Text(s).font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "3D2F60"))
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 試聴 + 当てる + Lv2文字開示

    @ViewBuilder
    private func previewButton(track: Track) -> some View {
        let hasVideo = track.hasYouTubeVideo
        let left = vm.previewPlaysLeft(trackId: track.id)
        let enabled = hasVideo && left > 0
        Button { vm.startPreview(trackId: track.id) } label: {
            Text(!hasVideo ? "試聴できません"
                 : left > 0 ? "▶ 少し聴く（あと\(left)回）"
                 : "本日の試聴回数を使い切りました")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(enabled ? .white : Color(hex: "B8ACD6"))
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(
                    enabled
                        ? LinearGradient(colors: [Color(hex: "79C7FF"), Color(hex: "5BA8F5")], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color(hex: "EDE8FF"), Color(hex: "EDE8FF")], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 16)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func actionBlock(track: Track) -> some View {
        VStack(spacing: 10) {
            previewButton(track: track)
            Text("30秒試聴は iTunes の公式プレビュー音源です（1曲1日3回まで）")
                .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "B8ACD6"))
            Button { showGuessAlert = true } label: {
                Text("曲名を当てる").buttonLabel(.pink)
            }
            if track.hintLevel < 2 {
                Button { pendingHint = .hint2; showAdModal = true } label: {
                    Text("ヒント②  曲名の文字を開く（広告）").buttonLabel(.secondary)
                }
            }
            if vm.hintTickets > 0 {
                Text("🎟️ ヒントチケット \(vm.hintTickets)枚所持 — 広告なしで解放されます")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(hex: "7248E0"))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    // MARK: - Lv3：Apple Music / Spotify で確認（広告なし）

    private func externalConfirm(track: Track) -> some View {
        let title = track.title ?? ""
        let artist = track.artistName ?? ""
        return VStack(alignment: .leading, spacing: 10) {
            Text("ヒント③  外部で確認する").font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
            Text("Apple Music / Spotify で聴いて曲名を確かめ、上の「曲名を当てる」で入力しよう")
                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            HStack(spacing: 10) {
                extBtn("Apple Music", icon: "music.note", bg: Color(hex: "FA2D48")) {
                    ExternalMusic.openAppleMusic(title: title, artist: artist)
                }
                extBtn("Spotify", icon: "music.note", bg: Color(hex: "1DB954")) {
                    ExternalMusic.openSpotify(title: title, artist: artist)
                }
            }
            Button { Task { await vm.addListenLater(trackId: trackId) } } label: {
                Text("あとで聴くに追加").buttonLabel(.secondary)
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    private func extBtn(_ label: String, icon: String, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: icon); Text(label) }
                .font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(bg, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Button label style (MLButtonStyle avoids conflict with SwiftUI ButtonStyle)

enum MLButtonStyle { case primary, secondary, pink, coin }

extension View {
    func buttonLabel(_ style: MLButtonStyle, small: Bool = false) -> some View {
        self
            .font(.system(size: small ? 11 : 12, weight: .black))
            .foregroundStyle(buttonFG(style))
            .frame(maxWidth: small ? nil : .infinity, minHeight: small ? 32 : 40)
            .padding(.horizontal, small ? 10 : 14)
            .background(buttonBG(style), in: RoundedRectangle(cornerRadius: small ? 13 : 16))
    }

    private func buttonFG(_ style: MLButtonStyle) -> Color {
        switch style {
        case .primary, .pink: return .white
        case .secondary:      return Color(hex: "7248E0")
        case .coin:           return Color(hex: "3a2400")
        }
    }

    private func buttonBG(_ style: MLButtonStyle) -> LinearGradient {
        switch style {
        case .primary:   return LinearGradient(colors: [Color(hex: "9670F0"), Color(hex: "7248E0")], startPoint: .top, endPoint: .bottom)
        case .secondary: return LinearGradient(colors: [Color(hex: "EDE8FF"), Color(hex: "E0D8F7")], startPoint: .top, endPoint: .bottom)
        case .pink:      return LinearGradient(colors: [Color(hex: "ff9fbd"), Color(hex: "ff7fa6")], startPoint: .top, endPoint: .bottom)
        case .coin:      return LinearGradient(colors: [Color(hex: "ffe28a"), Color(hex: "ffc85b")], startPoint: .top, endPoint: .bottom)
        }
    }
}
