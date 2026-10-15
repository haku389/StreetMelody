import SwiftUI

// MARK: - 見た目の土台（影・カード・背景）
//
// 以前は影がほぼ無く（不透明度 0.07 の1枚だけ）、カードと背景の差が縁の線だけで、
// 画面がのっぺりしていた。ここで奥行きの決まりを1か所に持ち、全画面で同じ深さを使う。
//
//  ・影は2枚重ねる。足元の短く濃い影（接地）＋広く淡い影（浮き）。
//    1枚だけだと、ぼやけた灰色の帯になって浮いて見えない。
//  ・影の色は黒ではなく、アプリの紫を暗くした色。黒い影は紫の画面で濁って見える。
//  ・背景は一枚色にしない。上の方にだけ淡いにじみを置き、カードの白との差を作る。

enum MLElevation { case low, mid, high }

extension View {
    /// 2枚重ねの影
    func mlShadow(_ e: MLElevation = .mid, tint: Color = Color(hex: "4B2FB0")) -> some View {
        let v: (r1: CGFloat, y1: CGFloat, o1: Double, r2: CGFloat, y2: CGFloat, o2: Double) = {
            switch e {
            case .low:  return (1.5, 1, 0.08, 8, 4, 0.10)
            case .mid:  return (2, 1, 0.08, 22, 12, 0.14)
            case .high: return (3, 2, 0.09, 30, 18, 0.18)
            }
        }()
        return self
            .shadow(color: tint.opacity(v.o1), radius: v.r1, y: v.y1)
            .shadow(color: tint.opacity(v.o2), radius: v.r2, y: v.y2)
    }

    /// 浮いた白いカード。上が光る細い縁と、2枚重ねの影
    func mlCard(radius: CGFloat = 24, elevation: MLElevation = .mid) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [.white, Color(hex: "FCFAFF")], startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white, Color(hex: "E4DBFA")], startPoint: .top, endPoint: .bottom),
                                  lineWidth: 1)
            }
            .mlShadow(elevation)
    }

    /// カードの中に置く小さなマス（数字の枠など）。浮かせず、少しくぼんで見せる。
    /// カード（浮く）とマス（沈む）で高さの差をつけると、平らに見えない。
    func mlInset(radius: CGFloat = 16) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "EBE4FF"), Color(hex: "F3EFFF")], startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color(hex: "DCD1F7"), .white], startPoint: .top, endPoint: .bottom),
                                  lineWidth: 1)
            }
    }

    /// 紫の主ボタンの光（色付きの影）
    func mlGlow(_ color: Color = Color(hex: "7248E0")) -> some View {
        self.shadow(color: color.opacity(0.32), radius: 12, y: 6)
    }
}

// MARK: - 画面の背景

struct MLBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "F4EEFF"), Color(hex: "F2ECFF"), Color(hex: "F8F5FF")],
                           startPoint: .top, endPoint: .bottom)
            // 上の方にだけ淡い色のにじみ（左に紫、右にピンク）
            GeometryReader { g in
                Circle().fill(Color(hex: "C4AEFF").opacity(0.50))
                    .frame(width: g.size.width * 0.95)
                    .blur(radius: 80)
                    .offset(x: -g.size.width * 0.35, y: -g.size.width * 0.55)
                Circle().fill(Color(hex: "FFC2DA").opacity(0.40))
                    .frame(width: g.size.width * 0.8)
                    .blur(radius: 80)
                    .offset(x: g.size.width * 0.45, y: -g.size.width * 0.35)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
