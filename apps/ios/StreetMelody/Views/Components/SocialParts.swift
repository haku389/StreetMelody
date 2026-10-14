import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - 人のアイコン
//
// 写真があれば写真、無ければ名前の頭文字。絵文字は使わない
// （iOS 26.3 のシミュレーターではカラー絵文字が「?」になる。記号と文字ならどこでも出る）。

struct UserAvatar: View {
    var image: UIImage? = nil
    var name: String = ""
    var size: CGFloat = 40
    var best: Bool = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "B79CFF"), Color(hex: "7248E0")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        if let c = initial {
                            Text(c).font(.system(size: size * 0.42, weight: .black)).foregroundStyle(.white)
                        } else {
                            Image(systemName: "music.note").font(.system(size: size * 0.42, weight: .bold)).foregroundStyle(.white)
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(alignment: .bottomTrailing) {
            if best {
                Image(systemName: "star.fill").font(.system(size: size * 0.24, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.4, height: size * 0.4)
                    .background(Color(hex: "E0A020"), in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }
        }
    }

    private var initial: String? {
        let t = name.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return t.first.map { String($0).uppercased() }
    }
}

// MARK: - メロディコイン

struct CoinIcon: View {
    var size: CGFloat = 18
    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [Color(hex: "FFE28A"), Color(hex: "F2B33D")], startPoint: .top, endPoint: .bottom))
            .overlay(Circle().stroke(Color(hex: "D99A1E").opacity(0.6), lineWidth: 1))
            .overlay(Image(systemName: "music.note").font(.system(size: size * 0.5, weight: .black)).foregroundStyle(Color(hex: "8A5A00")))
            .frame(width: size, height: size)
    }
}

// MARK: - 音楽サービスのアイコン
//
// 公式のアイコンは はく が各社のブランド素材ページから用意して
// Resources/ServiceIcons/ に置く（service_spotify.png など。README 参照）。
// 置かれるまでは、ブランド色の丸に記号を出しておく。

struct ServiceIcon: View {
    let service: String     // "spotify" | "appleMusic" | "youtubeMusic"
    var size: CGFloat = 32

    var body: some View {
        if let ui = UIImage(named: "service_\(service)") {
            Image(uiImage: ui).resizable().scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        } else {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(fallback.bg)
                .overlay(Image(systemName: fallback.symbol).font(.system(size: size * 0.48, weight: .bold)).foregroundStyle(.white))
                .frame(width: size, height: size)
        }
    }

    private var fallback: (bg: AnyShapeStyle, symbol: String) {
        switch service {
        case "spotify":      return (AnyShapeStyle(Color(hex: "1DB954")), "music.note")
        case "appleMusic":   return (AnyShapeStyle(LinearGradient(colors: [Color(hex: "FF5C73"), Color(hex: "FA233B")],
                                                                  startPoint: .top, endPoint: .bottom)), "music.note")
        case "youtubeMusic": return (AnyShapeStyle(Color(hex: "FF0000")), "play.fill")
        default:             return (AnyShapeStyle(Color(hex: "7248E0")), "music.note")
        }
    }
}

// MARK: - 小見出し・メニューのカード（StyleCare のマイページと同じ作り）

/// カードの外に置く小見出し
struct MLSectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .black)).foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18).padding(.bottom, 8)
    }
}

/// 1項目1枚のメニュー：色付きの四角いアイコン・項目名・説明・（数）・右矢印
struct MLMenuCard: View {
    let icon: String
    var tint: Color = Color(hex: "7248E0")
    let title: String
    var desc: String? = nil
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.13))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                    if let desc, !desc.isEmpty {
                        Text(desc).font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "7B6F8A")).lineLimit(2)
                    }
                }
                Spacer(minLength: 4)
                if badge > 0 { CountBadge(count: badge) }
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: "B8ACD6"))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mlCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 9)
    }
}

struct CountBadge: View {
    let count: Int
    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(Color(hex: "FF5C73"), in: Capsule())
    }
}

// MARK: - 自分のユーザーIDを写す
//
// IDは相手に打ってもらうもので、伝えるときは貼り付けるのが一番早い。
// 写すのは「@」を除いたID（追加の欄にそのまま貼れる形）。
// 写した印は時間で消さない ―― 貼り付け先から戻ってきたとき、押せたか分かるように。

struct CopyIdButton: View {
    let handle: String?
    var showsLabel: Bool = true
    @State private var copied = false

    var body: some View {
        Button {
            guard let h = handle, !h.isEmpty else { return }
            UIPasteboard.general.string = h
            copied = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                if showsLabel { Text(copied ? "コピーしました" : "IDをコピー") }
            }
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(copied ? Color(hex: "1A9E6E") : Color(hex: "7248E0"))
            .padding(.horizontal, showsLabel ? 10 : 7).padding(.vertical, 6)
            .background((copied ? Color(hex: "1A9E6E") : Color(hex: "7248E0")).opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(handle?.isEmpty ?? true)
        .sensoryFeedback(.success, trigger: copied)
    }
}

// MARK: - QR コード

struct QRCodeImage: View {
    let text: String

    var body: some View {
        if let ui = Self.make(text) {
            Image(uiImage: ui).interpolation(.none).resizable().scaledToFit()
        } else {
            Color.clear
        }
    }

    static func make(_ text: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
