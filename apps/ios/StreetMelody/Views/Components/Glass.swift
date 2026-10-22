import SwiftUI

// MARK: - Shared controls. Keep the public API, use the approved pastel clay finish.

extension View {
    /// Cream clay surface, consistently across supported OS versions.
    func mlGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        self.background(MLPalette.cream, in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.8), lineWidth: 1).allowsHitTesting(false))
            .mlShadow(.low)
    }

    /// Standard navigation behavior remains native; older OS versions use the cream surface.
    func mlNavBarBackground() -> some View { modifier(MLNavBarBackground()) }
}

private struct MLNavBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content.toolbarBackground(Color(hex: "FFF4ED"), for: .navigationBar)
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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(on ? Color.white : MLPalette.muted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            if on {
                                Capsule()
                                    .fill(MLPalette.button)
                                    .shadow(color: Color(hex: "A27BC8").opacity(0.15), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(MLPressButtonStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .mlGlass(in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Rounded icon button with the shared cream surface and clay shadow.

struct GlassIconButton: View {
    let systemName: String
    var size: CGFloat = 38
    var tint: Color = Color(hex: "A27BC8")
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
        .buttonStyle(MLPressButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct GlassCircle: ViewModifier {
    func body(content: Content) -> some View {
        content.background(MLPalette.cream, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.8)))
            .mlShadow(.low)
    }
}
