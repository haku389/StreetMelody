import SwiftUI

// MARK: - タブ画面の枠（スクロール追従ヘッダー）
//
// StyleCare の HomeScreen のヘッダーと同じ作り:
//   ・ヘッダーは中身の上に重ね、ぼかしで背後を透かす
//   ・上段（タイトルなど）は下へ送ると隠れ、上へ戻すと出る
//   ・pinned（レベルバー・区分切替など）は隠さず画面上端に残す
// 上段を隠しても中身の余白は変えない（変えると中身が跳ねて、スクロール量の判定が揺れる）。
//
// ぼかしは「中身がヘッダーの下に潜っているあいだ」だけ出す（OS 標準のバーと同じ）。
// スクロール量を測れるのは iOS 18 以降。iOS 17 は上段を隠さず、ぼかしも常に出す
// （出さないと、潜った中身と文字が重なって読めない）。

struct MLTabScreen<Top: View, Pinned: View, Content: View>: View {
    private let top: Top
    private let pinned: Pinned
    private let content: Content

    @State private var topHidden = false
    @State private var scrolled = false
    @State private var topH: CGFloat = 0
    @State private var pinnedH: CGFloat = 0

    init(@ViewBuilder top: () -> Top,
         @ViewBuilder pinned: () -> Pinned,
         @ViewBuilder content: () -> Content) {
        self.top = top(); self.pinned = pinned(); self.content = content()
    }

    private var hasPinned: Bool { Pinned.self != EmptyView.self }

    var body: some View {
        ZStack(alignment: .top) {
            MLBackground()

            ScrollView {
                content
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 112)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.top, topH + pinnedH, for: .scrollContent)
            .modifier(ScrollTracking(topHidden: $topHidden, scrolled: $scrolled, hideAfter: topH))

            header
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            top
                .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(HeightReader(height: $topH))
                .opacity(topHidden ? 0 : 1)
                .allowsHitTesting(!topHidden)
            if hasPinned {
                pinned
                    .padding(.horizontal, 18).padding(.bottom, 10)
                    .frame(maxWidth: .infinity)
                    .modifier(HeightReader(height: $pinnedH))
            }
        }
        .background(alignment: .bottom) {
            Rectangle().fill(Color(hex: "7248E0").opacity(0.10)).frame(height: 0.5)
                .opacity(showsBlur ? 1 : 0)
        }
        .background(.bar.opacity(showsBlur ? 1 : 0), ignoresSafeAreaEdges: .top)
        .offset(y: topHidden ? -topH : 0)
        .animation(.easeOut(duration: 0.18), value: scrolled)
    }

    private var showsBlur: Bool {
        if #available(iOS 18.0, *) { return scrolled } else { return true }
    }
}

extension MLTabScreen where Pinned == EmptyView {
    init(@ViewBuilder top: () -> Top, @ViewBuilder content: () -> Content) {
        self.init(top: top, pinned: { EmptyView() }, content: content)
    }
}

/// タブ画面の見出し（タイトル＋ひとこと）
struct MLTabTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 22, weight: .black)).foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle).font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 部品

private struct HeightReader: ViewModifier {
    @Binding var height: CGFloat
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { g in
                Color.clear
                    .onAppear { height = g.size.height }
                    .onChange(of: g.size.height) { _, h in height = h }
            }
        )
    }
}

private struct ScrollPos: Equatable { var y: CGFloat; var maxY: CGFloat }

/// 下へ送ったら上段を隠し、上へ戻したら出す。先頭付近では必ず出す。
private struct ScrollTracking: ViewModifier {
    @Binding var topHidden: Bool
    @Binding var scrolled: Bool
    /// 上段の高さ。中身がこれだけ流れるまでは隠さない
    /// （早く隠すと、上段が抜けた所に何も無い帯が見える）
    let hideAfter: CGFloat

    /// これより小さい動きは無視する（指の震えで出たり消えたりしないように）
    private let threshold: CGFloat = 8

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: ScrollPos.self) { g in
                let y = g.contentOffset.y + g.contentInsets.top
                let maxY = g.contentSize.height + g.contentInsets.top + g.contentInsets.bottom - g.containerSize.height
                return ScrollPos(y: y, maxY: maxY)
            } action: { old, new in
                let isScrolled = new.y > 1
                if isScrolled != scrolled { scrolled = isScrolled }
                if new.y <= hideAfter { setHidden(false); return }
                // 下端で跳ね返るときの戻りは「上へ戻した」と数えない（出たり消えたりする）
                if new.y >= new.maxY - 4 || old.y >= old.maxY - 4 { return }
                let d = new.y - old.y
                if d > threshold { setHidden(true) } else if d < -threshold { setHidden(false) }
            }
        } else {
            content
        }
    }

    private func setHidden(_ v: Bool) {
        guard v != topHidden else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { topHidden = v }
    }
}
