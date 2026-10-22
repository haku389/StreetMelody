import SwiftUI

/// Shared with the approved Web prototype and Android MelodyColors.
enum MLPalette {
    static let ink = Color(hex: "49335F")
    static let muted = Color(hex: "8D7694")
    static let primary = Color(hex: "A27BC8")
    static let cream = Color(hex: "FFF4ED")
    static let lilac = Color(hex: "EEE0F2")
    static let rose = Color(hex: "F6D9D7")
    static let honey = Color(hex: "F5E4C6")
    static let shadow = Color(hex: "80618B")
    static let button = LinearGradient(colors: [Color(hex: "C3A2E4"), primary], startPoint: .top, endPoint: .bottom)
}

enum MLElevation { case low, mid, high }

extension View {
    func mlShadow(_ elevation: MLElevation = .mid, tint: Color = MLPalette.shadow) -> some View {
        let depth: (CGFloat, CGFloat, Double) = {
            switch elevation {
            case .low: return (4, 2, 0.10)
            case .mid: return (7, 4, 0.14)
            case .high: return (15, 9, 0.19)
            }
        }()
        return self
            .shadow(color: tint.opacity(0.10), radius: 1.5, y: 1)
            .shadow(color: tint.opacity(depth.2), radius: depth.0, y: depth.1)
    }

    func mlCard(radius: CGFloat = 24, elevation: MLElevation = .mid) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "FFF8F2"), Color(hex: "FAEEE8")], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white, Color.white.opacity(0.45)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .mlShadow(elevation)
    }

    func mlInset(radius: CGFloat = 16, tint: Color = MLPalette.lilac) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.25)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .mlShadow(.low)
    }

    func mlGlow(_ color: Color = MLPalette.primary) -> some View {
        shadow(color: color.opacity(0.25), radius: 5, y: 4)
    }
}

struct MLBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: "FFF9F3"), MLPalette.cream, Color(hex: "F5EAF2")], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

/// Uses Button's native press lifecycle: release activates, a cancelled gesture restores the appearance.
struct MLPressFeedback: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .brightness(isPressed ? -0.06 : 0)
            .opacity(isPressed ? 0.82 : 1)
            .scaleEffect(isPressed && !reduceMotion ? 0.965 : 1)
            .offset(y: isPressed && !reduceMotion ? 2 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: isPressed ? 0.08 : 0.16), value: isPressed)
    }
}

/// Keeps each existing label and surface; adds a persistent pressed appearance.
struct MLPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(MLPressFeedback(isPressed: configuration.isPressed))
    }
}

struct MLClayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(MLPalette.button, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.45)))
            .shadow(color: MLPalette.shadow.opacity(configuration.isPressed ? 0.05 : 0.16), radius: configuration.isPressed ? 1 : 4, y: configuration.isPressed ? 1 : 3)
            .modifier(MLPressFeedback(isPressed: configuration.isPressed))
    }
}

/// Ceramic cream pill with a lilac headphone-inspired note badge.
struct MLHeroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color(hex: "76558D"))
            .padding(.leading, 7).padding(.trailing, 12).padding(.vertical, 7)
            .frame(minHeight: 44)
            .background(LinearGradient(colors: [Color(hex: "FFFDF3"), Color(hex: "F5E9DF")], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: "D8C4DF")))
            .shadow(color: Color(hex: "BAA1C5").opacity(configuration.isPressed ? 0.12 : 0.3), radius: configuration.isPressed ? 1 : 4, y: configuration.isPressed ? 1 : 3)
            .modifier(MLPressFeedback(isPressed: configuration.isPressed))
    }
}

struct MLWelcomeHero: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let action: () -> Void

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    Image("PastelHero").resizable().scaledToFill()
                        .frame(height: 180).clipped().accessibilityHidden(true)
                    copy.padding([.horizontal, .bottom], 20)
                }
                .background(MLPalette.lilac)
            } else {
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        Image("PastelHero").resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: 240).clipped()
                            .accessibilityHidden(true)
                        copy
                            .frame(width: geometry.size.width * 0.51, alignment: .leading)
                            .padding(.leading, geometry.size.width * 0.45)
                            .padding(.top, 25)
                    }
                }
                .frame(height: 240)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.5)))
        .mlShadow()
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A LITTLE MUSIC, A LITTLE MAGIC")
                .font(.system(size: 6, weight: .medium)).tracking(0.4)
                .foregroundStyle(Color(hex: "785A91"))
                .padding(6).background(.white.opacity(0.4), in: Capsule())
            Text("いつもの道に、\n新しいメロディ。")
                .font(.system(size: 22, weight: .bold)).tracking(-0.8)
                .foregroundStyle(MLPalette.ink).fixedSize(horizontal: false, vertical: true)
            Text("すれちがうたび、好きな音が増えていく。")
                .font(.system(size: 10)).foregroundStyle(Color(hex: "745887"))
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(hex: "FFF9EE"))
                        .frame(width: 28, height: 28)
                        .background(MLPalette.button, in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.4)))
                    Text("届いたメロディ")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium)).foregroundStyle(Color(hex: "AE8ABD"))
                }
            }
            .buttonStyle(MLHeroButtonStyle())
        }
    }
}

/// Compact introduction shared by the secondary tabs. No decorative image obscures the content.
struct MLTabSummary: View {
    let symbol: String
    let title: String
    let caption: String
    var metrics: [(String, String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 49, height: 49)
                    .background(MLPalette.button, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.55)))
                    .mlShadow(.low)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(MLPalette.ink)
                    Text(caption).font(.system(size: 11)).foregroundStyle(MLPalette.muted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if !metrics.isEmpty {
                HStack(spacing: 10) {
                    ForEach(metrics.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(metrics[index].0).font(.system(size: 9)).foregroundStyle(MLPalette.muted)
                            Text(metrics[index].1).font(.system(size: 22, weight: .bold)).foregroundStyle(MLPalette.ink)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(13)
                        .mlInset(radius: 17, tint: [MLPalette.lilac, MLPalette.rose, MLPalette.honey][index % 3])
                    }
                }
            }
        }.padding(20).mlCard()
    }
}
