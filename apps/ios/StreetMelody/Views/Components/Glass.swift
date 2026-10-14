import SwiftUI

// MARK: - Liquid Glass の共通部品（StyleCare の flags.js / GlassSegment / GlassIconButton に合わせた切り分け）
//
// iOS 26 以降は OS の Liquid Glass（後ろが透けて歪む。ぼかしとは別物）を使う。
// それ未満はぼかし素材に倒す。真似たガラスは溶け合いや泡の動きまで届かないので、
// 本物が無い端末で無理に再現しない。

extension View {
    /// 板にガラスを敷く。iOS 26 は Liquid Glass、それ未満はぼかし素材＋細い縁。
    @ViewBuilder
    func mlGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(interactive ? Glass.regular.interactive() : Glass.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.6), lineWidth: 0.5))
        }
    }

    /// 詳細画面のナビゲーションバー。
    /// iOS 26 は OS のガラス＋スクロール端のぼかしに任せる（不透明に塗ると消える）。
    /// それ未満は従来どおり背景色で塗る。
    func mlNavBarBackground() -> some View { modifier(MLNavBarBackground()) }
}

private struct MLNavBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content.toolbarBackground(Color(hex: "F5F0FF"), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - GlassSegment（区分の切り替え。ガラスの上を白いピルが滑る）

struct GlassSegment<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let label: (Item) -> String

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                let on = item == selection
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { selection = item }
                } label: {
                    Text(label(item))
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(on ? Color(hex: "7248E0") : Color(hex: "8A7FA6"))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if on {
                                Capsule()
                                    .fill(Color.white.opacity(0.95))
                                    .shadow(color: Color(hex: "7248E0").opacity(0.15), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .mlGlass(in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - GlassIconButton（記号だけのボタン）
//
// iOS 26 以降は記号の下に丸いガラスを敷く。それ未満は何も足さない
// （ガラスの無いところで丸い板だけ置くと、ただの灰色の丸が増えるだけ）。
// 大きさと当たり判定はどちらも同じにして、ボタンの位置がずれないようにする。

struct GlassIconButton: View {
    let systemName: String
    var size: CGFloat = 38
    var tint: Color = Color(hex: "7248E0")
    var accessibilityLabel: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .modifier(GlassCircle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct GlassCircle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
        }
    }
}
