import SwiftUI

struct PuzzleCompleteOverlay: View {
    let trackId: String
    @EnvironmentObject var vm: AppViewModel
    @State private var appear = false

    private var track: Track? { vm.track(for: trackId) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
                .opacity(appear ? 1 : 0)

            if let t = track {
                card(track: t)
                    .scaleEffect(appear ? 1 : 0.55)
                    .offset(y: appear ? 0 : 40)
                    .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
                appear = true
            }
        }
    }

    private func card(track: Track) -> some View {
        VStack(spacing: 0) {
            // 完成したパズル全体（6×4 サムネイル）
            PuzzlePiecesView(ownedPieces: track.ownedPieces,
                             color: track.color,
                             seed: track.id,
                             thumbnailURL: track.thumbnailURL,
                             cornerRadius: 16,
                             revealAll: true)
                .padding(.bottom, 18)

            // Celebration text
            VStack(spacing: 6) {
                Text("🎉")
                    .font(.system(size: 24))
                Text("パズル完成！")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Text(track.title ?? "—")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.9))
                Text(track.artistName ?? "—")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color(hex: "817992"))
            }
            .padding(.bottom, 16)

            // Reward badges
            HStack(spacing: 8) {
                rewardBadge(icon: "🧩", text: "\(track.ownedPieces.count) / \(track.pieceCount) 完成",
                            bg: Color(hex: "8f6df4").opacity(0.25), border: Color(hex: "8f6df4").opacity(0.4),
                            fg: Color(hex: "c4a8ff"))
                rewardBadge(icon: "🪙", text: "+\(track.rewardCoins) コイン",
                            bg: Color(hex: "f9c74f").opacity(0.2), border: Color(hex: "f9c74f").opacity(0.4),
                            fg: Color(hex: "f9c74f"))
                rewardBadge(icon: "⭐", text: "+\(track.rewardExp) EXP",
                            bg: Color(hex: "6ee7b7").opacity(0.18), border: Color(hex: "6ee7b7").opacity(0.4),
                            fg: Color(hex: "6ee7b7"))
            }
            .padding(.bottom, 18)

            // Buttons
            VStack(spacing: 8) {
                Button {
                    vm.dismissPuzzleComplete()
                    vm.activeTab = .collection
                    vm.navigationStack = []
                    vm.collectionTab = .puzzles
                } label: {
                    Text("コレクションで見る")
                        .font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(LinearGradient(colors: [Color(hex: "8f6df4"), Color(hex: "6041d0")],
                                                   startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button {
                    vm.dismissPuzzleComplete()
                } label: {
                    Text("閉じる")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(
            LinearGradient(colors: [Color(hex: "1e0e3c"), Color(hex: "0d1a3a")],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28)
        )
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.14)))
        .shadow(color: .black.opacity(0.7), radius: 32, y: 16)
        .padding(.horizontal, 24)
    }

    private func rewardBadge(icon: String, text: String, bg: Color, border: Color, fg: Color) -> some View {
        HStack(spacing: 3) {
            Text(icon).font(.system(size: 10))
            Text(text).font(.system(size: 9, weight: .black)).foregroundStyle(fg)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(bg, in: Capsule())
        .overlay(Capsule().stroke(border))
    }
}

// MARK: - Title Celebration Overlay

struct TitleCelebrationOverlay: View {
    let titleId: String
    @EnvironmentObject var vm: AppViewModel
    @State private var appear = false
    @State private var iconPulse = false

    private var titleItem: TitleItem? { vm.titles.first { $0.id == titleId } }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
                .opacity(appear ? 1 : 0)

            if let t = titleItem {
                VStack(spacing: 0) {
                    Text("TITLE UNLOCKED")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2.5)
                        .foregroundStyle(Color(hex: "f9c74f"))
                        .padding(.bottom, 14)

                    Text(t.icon)
                        .font(.system(size: 52))
                        .scaleEffect(iconPulse ? 1.12 : 1.0)
                        .rotationEffect(.degrees(iconPulse ? 4 : -4))
                        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: iconPulse)
                        .padding(.bottom, 14)

                    Text("称号「\(t.name)」を獲得！")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.bottom, 6)

                    Text(t.description)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 14)

                    HStack(spacing: 8) {
                        rewardBadge(text: "🪙 +\(t.rewardCoins) コイン",
                                    bg: Color(hex: "f9c74f").opacity(0.2), border: Color(hex: "f9c74f").opacity(0.4), fg: Color(hex: "f9c74f"))
                        rewardBadge(text: "⭐ +\(t.rewardExp) EXP",
                                    bg: Color(hex: "6ee7b7").opacity(0.16), border: Color(hex: "6ee7b7").opacity(0.4), fg: Color(hex: "6ee7b7"))
                    }
                    .padding(.bottom, 18)

                    if vm.pendingTitleCelebrations.count > 1 {
                        Text("ほかに\(vm.pendingTitleCelebrations.count - 1)件の称号を獲得しています")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.bottom, 10)
                    }

                    Button {
                        vm.dismissTitleCelebration()
                    } label: {
                        Text("やったね！")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color(hex: "3a2400"))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(LinearGradient(colors: [Color(hex: "f9c74f"), Color(hex: "f0a04b")],
                                                       startPoint: .leading, endPoint: .trailing),
                                        in: RoundedRectangle(cornerRadius: 15))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22).padding(.vertical, 26)
                .frame(maxWidth: 300)
                .background(
                    LinearGradient(colors: [Color(hex: "2a1450"), Color(hex: "141c40")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 26)
                )
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color(hex: "f9c74f").opacity(0.35)))
                .shadow(color: .black.opacity(0.65), radius: 28, y: 14)
                .scaleEffect(appear ? 1 : 0.6)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appear = true }
            iconPulse = true
        }
    }

    private func rewardBadge(text: String, bg: Color, border: Color, fg: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black)).foregroundStyle(fg)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(bg, in: Capsule())
            .overlay(Capsule().stroke(border))
    }
}
