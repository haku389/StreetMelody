import SwiftUI

struct AdConfirmModal: View {
    let kind: HintKind
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var rewardLabel: String {
        switch kind {
        case .hint1:  return "ジャンル・年代・雰囲気のヒント"
        case .hint2:  return "曲名の文字を一部開く"
        case .answer: return "ヒント"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                Spacer().frame(height: 28)
                Text("広告を視聴してヒントを解放しますか？")
                    .font(.system(size: 16, weight: .black))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Text("視聴すると以下の内容を解放できます。")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color(hex: "817992"))
                    .padding(.top, 8)

                VStack(spacing: 4) {
                    Text("解放内容")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "817992"))
                    Text(rewardLabel).font(.system(size: 15, weight: .black))
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color(hex: "fff4df"), in: RoundedRectangle(cornerRadius: 18))
                .padding(.top, 16).padding(.horizontal, 22)

                Text("※広告視聴後はキャンセルできません")
                    .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "817992")).padding(.top, 10)
                Text("（広告SDKは後日実装。現在は視聴を省略して解放します）")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "b3a8c4"))
                    .multilineTextAlignment(.center).padding(.top, 4).padding(.horizontal, 22)

                HStack(spacing: 10) {
                    Button("いいえ") { dismiss() }
                        .buttonLabel(.secondary)
                    Button("視聴する") { dismiss(); onConfirm() }
                        .buttonLabel(.primary)
                }
                .padding(.top, 14).padding(.horizontal, 22).padding(.bottom, 28)
            }
            Image(systemName: "figure.wave")
                .font(.system(size: 60)).foregroundStyle(Color(hex: "c0adff")).offset(x: -12, y: 6)
        }
        .background(Color(hex: "fffefd"), in: RoundedRectangle(cornerRadius: 28))
        .overlay(
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .heavy))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: "f8f1ff"), in: Circle())
            }
            .padding(12),
            alignment: .topTrailing
        )
        .padding(24)
        .presentationDetents([.fraction(0.5)])
        .presentationDragIndicator(.visible)
    }
}
