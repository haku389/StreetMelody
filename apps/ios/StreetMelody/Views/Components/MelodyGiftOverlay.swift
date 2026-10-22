import SwiftUI
import SceneKit
import UIKit

// ─────────────────────────────────────────────────────────────
//  今日のメロディのプレゼント（開封の演出）
//
//  その日に届いたメロディがあり、今日まだ開けていなければ、起動して読み込みが終わったところで
//  1日1回だけ出す。立体の箱が落ちてきて弾み、押すと（押さなくても少し待つと）震えてから
//  ふたが飛び、光と紙吹雪と音符が出て、届いた数を数え上げる。
//
//  立体は SceneKit（OS に入っている 3D。追加の部品は要らない）。数字・ボタン・光の筋は SwiftUI。
//  「視差効果を減らす」の人には、動かさずに結果だけを出す。
// ─────────────────────────────────────────────────────────────

// MARK: - いつ出すか

extension AppViewModel {
    private static let melodyGiftDayKey = "streetmelody.melodyGift.lastDay"

    /// 今日のメロディが届いていて、今日まだ開けていなければ出す（1日1回）。
    /// プロフィールの登録やパズル完成の演出が出ているときは、それが閉じてから
    func presentMelodyGiftIfNeeded() {
        guard melodyGiftCount == nil, !isLoading, !isGuestAccount, !showProfileEdit, puzzleCompleteTrackId == nil else { return }
        let count = pendingEncounterCount
        guard count > 0 else { return }
        let today = Self.melodyGiftDay(Date())
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: Self.melodyGiftDayKey) != today else { return }
        defaults.set(today, forKey: Self.melodyGiftDayKey)
        melodyGiftCount = count
    }

    func closeMelodyGift(openMelodies: Bool) {
        withAnimation(.easeOut(duration: 0.25)) { melodyGiftCount = nil }
        if openMelodies { activeTab = .melody }
    }

    private static func melodyGiftDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - 画面

struct MelodyGiftOverlay: View {
    let count: Int
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var gift = GiftScene()

    private enum Phase { case arriving, waiting, opening, opened }
    @State private var phase: Phase = .arriving
    @State private var backdrop = false
    @State private var shown = 0
    @State private var flash = false
    @State private var flashArmed = false   // ふたが飛ぶまでは光を出さない（震えているあいだ、箱の前に白い点が残った）
    @State private var cardIn = false

    var body: some View {
        ZStack {
            // 後ろのホームはぼかして沈める（透けると箱に目が行かない）
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(colors: [Color(hex: "241238"), Color(hex: "4A2668"), Color(hex: "6B3A7E")],
                               startPoint: .top, endPoint: .bottom)
                    .opacity(0.9)
            }
            .ignoresSafeArea()
            .opacity(backdrop ? 1 : 0)

            if !reduceMotion { TwinkleField().opacity(backdrop ? 1 : 0).allowsHitTesting(false) }

            VStack(spacing: 0) {
                Spacer(minLength: 24)
                headline.frame(height: 92)

                // 光の筋とふたが飛んだ瞬間の光は画面より大きいので、背景・前景に置いて
                // 並びの幅に入れない（入れると画面全体が横にずれる）
                Group {
                    if reduceMotion {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 110, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [Color(hex: "C9A6F2"), Color(hex: "F2A7C9")],
                                                            startPoint: .top, endPoint: .bottom))
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .background {
                    LightRays()
                        .frame(width: 560, height: 560)
                        .scaleEffect(isOpen ? 1 : 0.15)
                        .opacity(isOpen ? 1 : 0)
                        .animation(.spring(response: 0.7, dampingFraction: 0.75), value: isOpen)
                        .allowsHitTesting(false)
                }
                .overlay {
                    // 立体は画面の高さぶん描く。紙吹雪が上へ飛んでも枠で切れないように。
                    // 並びには入れない（overlay）ので、箱の位置はこの 360 の真ん中のまま
                    if !reduceMotion {
                        GiftSceneView(gift: gift)
                            .frame(width: UIScreen.main.bounds.width, height: 760)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    Circle()
                        .fill(RadialGradient(colors: [.white, Color(hex: "FFE6A8").opacity(0.7), .clear],
                                             center: .center, startRadius: 0, endRadius: 220))
                        .frame(width: 440, height: 440)
                        .scaleEffect(flash ? 1.4 : 0.2)
                        .opacity(flashArmed ? (flash ? 0 : 1) : 0)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .onTapGesture { open() }
                .accessibilityElement()
                .accessibilityLabel("メロディのプレゼント")
                .accessibilityHint(phase == .waiting ? "開ける" : "")
                .accessibilityAddTraits(phase == .waiting ? .isButton : [])

                resultCard
                    .opacity(cardIn ? 1 : 0)
                    .offset(y: cardIn ? 0 : 60)
                    .scaleEffect(cardIn ? 1 : 0.92)
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: start)
    }

    private var isOpen: Bool { phase == .opening || phase == .opened }

    // MARK: 見出し（開ける前）

    private var headline: some View {
        VStack(spacing: 8) {
            Text("TODAY'S MELODY GIFT")
                .font(.system(size: 10, weight: .heavy)).tracking(2.4)
                .foregroundStyle(Color(hex: "F5D27A"))
            Text(phase == .opened ? "プレゼントを開けました" : "メロディのプレゼントが届きました")
                .font(.system(size: 19, weight: .black)).foregroundStyle(.white)
                .contentTransition(.opacity)
            Text("タップして開けよう")
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(.white.opacity(0.75))
                .opacity(phase == .waiting ? 1 : 0)
                .phaseAnimator([false, true]) { v, on in v.opacity(on ? 1 : 0.45) } animation: { _ in .easeInOut(duration: 0.8) }
        }
        .opacity(backdrop ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: phase)
    }

    // MARK: 結果（数を数え上げる）

    private var resultCard: some View {
        VStack(spacing: 6) {
            Text("今日のメロディ")
                .font(.system(size: 11, weight: .heavy)).foregroundStyle(MLPalette.muted)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(shown)")
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "9B6FE0"), Color(hex: "E86FA6")],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                    .contentTransition(.numericText(value: Double(shown)))
                    .monospacedDigit()
                Text("件").font(.system(size: 24, weight: .black)).foregroundStyle(MLPalette.ink)
            }
            Text("メロディが届きました！")
                .font(.system(size: 18, weight: .black)).foregroundStyle(MLPalette.ink)
            Text("すれちがった人の推し曲が、パズルのピースになって届いています")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(MLPalette.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 2).padding(.bottom, 10)
            Button { vm.closeMelodyGift(openMelodies: true) } label: {
                Text("メロディを受け取る").buttonLabel(.primary)
            }
            Button { vm.closeMelodyGift(openMelodies: false) } label: {
                Text("あとで").font(.system(size: 12, weight: .heavy)).foregroundStyle(MLPalette.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [.white, Color(hex: "FFF4ED")], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color(hex: "F5D27A"), Color(hex: "E86FA6"), Color(hex: "9B6FE0")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
        )
        .shadow(color: Color(hex: "F5D27A").opacity(0.35), radius: 24, y: 6)
        .allowsHitTesting(cardIn)
    }

    // MARK: 流れ

    private func start() {
        withAnimation(.easeOut(duration: 0.35)) { backdrop = true }
        if reduceMotion {
            phase = .opened
            shown = count
            withAnimation(.easeOut(duration: 0.3)) { cardIn = true }
            return
        }
        gift.playIntro()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(620))
            Haptics.impact(.heavy)          // 着地
            try? await Task.sleep(for: .milliseconds(380))
            if phase == .arriving { phase = .waiting }
            // 押されなくても、少し待てば自分で開く
            try? await Task.sleep(for: .seconds(2.6))
            if phase == .waiting { open() }
        }
    }

    private func open() {
        guard phase == .waiting || phase == .arriving else { return }
        phase = .opening
        gift.open()
        Task { @MainActor in
            // 震え（ためを作る）
            for i in 0..<6 {
                Haptics.impact(i < 3 ? .light : .medium)
                try? await Task.sleep(for: .milliseconds(70))
            }
            // ふたが飛ぶ
            Haptics.notify(.success)
            Haptics.impact(.heavy)
            flashArmed = true
            withAnimation(.easeOut(duration: 0.75)) { flash = true }
            try? await Task.sleep(for: .milliseconds(650))
            phase = .opened
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) { cardIn = true }
            try? await Task.sleep(for: .milliseconds(250))
            // 数え上げ。1つずつ軽く震わせる
            let step = max(0.045, min(0.16, 0.9 / Double(max(count, 1))))
            for i in 1...max(count, 1) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { shown = min(i, count) }
                Haptics.selection()
                try? await Task.sleep(for: .seconds(step))
            }
            Haptics.notify(.success)
        }
    }
}

// MARK: - 触覚

private enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let g = UIImpactFeedbackGenerator(style: style); g.prepare(); g.impactOccurred()
    }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - 光の筋（開いたあと、箱の後ろでゆっくり回る）

private struct LightRays: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let angle = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 24) / 24 * 360
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = min(size.width, size.height) / 2
                let rays = 14
                for i in 0..<rays {
                    let a0 = Angle.degrees(Double(i) / Double(rays) * 360 + angle)
                    let a1 = Angle.degrees(a0.degrees + 360 / Double(rays) * 0.45)
                    var p = Path()
                    p.move(to: c)
                    p.addArc(center: c, radius: r, startAngle: a0, endAngle: a1, clockwise: false)
                    p.closeSubpath()
                    let tint = i.isMultiple(of: 2) ? Color(hex: "F5D27A") : Color(hex: "F2A7C9")
                    ctx.fill(p, with: .radialGradient(Gradient(colors: [tint.opacity(0.55), tint.opacity(0)]),
                                                      center: c, startRadius: 30, endRadius: r))
                }
            }
            .blur(radius: 6)
        }
    }
}

// MARK: - 背景のきらめき

private struct TwinkleField: View {
    private let stars: [(x: CGFloat, y: CGFloat, s: CGFloat, d: Double)] = (0..<18).map { i in
        var h = UInt64(i + 7) &* 0x9E3779B97F4A7C15
        func next() -> CGFloat { h = h &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((h >> 33) % 1000) / 1000 }
        return (next(), next(), 6 + next() * 10, Double(next()) * 1.2)
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(stars.enumerated()), id: \.offset) { _, st in
                Image(systemName: "sparkle")
                    .font(.system(size: st.s, weight: .bold))
                    .foregroundStyle(Color(hex: "F5D27A"))
                    .position(x: st.x * geo.size.width, y: st.y * geo.size.height)
                    .phaseAnimator([0.15, 0.9]) { v, o in v.opacity(o).scaleEffect(o) } animation: { _ in
                        .easeInOut(duration: 1.1 + st.d)
                    }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 立体の箱（SceneKit）

private struct GiftSceneView: UIViewRepresentable {
    let gift: GiftScene

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(frame: .zero)
        v.scene = gift.scene
        v.backgroundColor = .clear
        v.isOpaque = false
        v.antialiasingMode = .multisampling4X
        v.rendersContinuously = true
        v.isPlaying = true
        v.allowsCameraControl = false
        v.isUserInteractionEnabled = false   // 押すのは SwiftUI 側で受ける
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

/// 箱を組み立てて、落とす・揺らす・開ける
@MainActor
final class GiftScene: ObservableObject {
    let scene = SCNScene()
    private let root = SCNNode()     // 箱全体（落ちる・揺れる）
    private let lid = SCNNode()      // ふた（飛ぶ）
    private let mouth = SCNNode()    // 箱の口（光と紙吹雪が出る所）
    private let innerLight = SCNNode()

    private let boxW: CGFloat = 1.5
    private let boxH: CGFloat = 1.15
    private let lidH: CGFloat = 0.3

    init() { build() }

    // MARK: 組み立て

    private func build() {
        scene.background.contents = UIColor.clear

        let cam = SCNCamera()
        // 横の画角で決める（描く範囲を縦に伸ばしても、箱の大きさが変わらない）
        cam.projectionDirection = .horizontal
        cam.fieldOfView = 31
        cam.wantsHDR = true
        // 光のにじみ。強すぎると白く飛び、明るすぎる点が黒い四角に化ける
        cam.bloomIntensity = 0.55
        cam.bloomThreshold = 0.95
        cam.bloomBlurRadius = 12
        cam.wantsExposureAdaptation = false
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(0, 1.9, 7.6)
        camNode.look(at: SCNVector3(0, 0.35, 0))
        scene.rootNode.addChildNode(camNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(red: 0.85, green: 0.78, blue: 1.0, alpha: 1)
        ambient.light?.intensity = 420
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1150
        key.light?.castsShadow = true
        key.light?.shadowMode = .deferred
        key.light?.shadowColor = UIColor(white: 0, alpha: 0.35)
        key.light?.shadowRadius = 10
        key.light?.shadowSampleCount = 16
        key.eulerAngles = SCNVector3(-0.95, -0.55, 0)
        scene.rootNode.addChildNode(key)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .omni
        rim.light?.color = UIColor(red: 1.0, green: 0.62, blue: 0.82, alpha: 1)
        rim.light?.intensity = 900
        rim.position = SCNVector3(2.6, 2.2, -2.8)
        scene.rootNode.addChildNode(rim)

        // 影だけを受ける床
        let floor = SCNFloor()
        floor.reflectivity = 0
        let floorMat = SCNMaterial()
        floorMat.lightingModel = .shadowOnly
        floor.materials = [floorMat]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position.y = Float(-boxH / 2)
        scene.rootNode.addChildNode(floorNode)

        scene.rootNode.addChildNode(root)

        let paper = Self.paperMaterial()
        let ribbon = Self.ribbonMaterial()

        // 箱
        let bodyGeo = SCNBox(width: boxW, height: boxH, length: boxW, chamferRadius: 0.06)
        bodyGeo.materials = [paper]
        let body = SCNNode(geometry: bodyGeo)
        body.castsShadow = true
        root.addChildNode(body)
        body.addChildNode(Self.band(width: 0.26, height: boxH + 0.012, length: boxW + 0.02, ribbon))
        body.addChildNode(Self.band(width: boxW + 0.02, height: boxH + 0.012, length: 0.26, ribbon))

        // ふた（リボンとちょう結び付き）
        let lidGeo = SCNBox(width: boxW + 0.12, height: lidH, length: boxW + 0.12, chamferRadius: 0.05)
        lidGeo.materials = [paper]
        lid.geometry = lidGeo
        lid.position.y = Float(boxH / 2 + lidH / 2 - 0.04)
        lid.addChildNode(Self.band(width: 0.27, height: lidH + 0.012, length: boxW + 0.14, ribbon))
        lid.addChildNode(Self.band(width: boxW + 0.14, height: lidH + 0.012, length: 0.27, ribbon))
        let bow = Self.bow(ribbon)
        bow.position.y = Float(lidH / 2)
        lid.addChildNode(bow)
        root.addChildNode(lid)

        mouth.position.y = Float(boxH / 2)
        root.addChildNode(mouth)

        innerLight.light = SCNLight()
        innerLight.light?.type = .omni
        innerLight.light?.color = UIColor(red: 1.0, green: 0.86, blue: 0.55, alpha: 1)
        innerLight.light?.intensity = 0
        innerLight.light?.attenuationEndDistance = 6
        // ふたやちょう結びに近すぎると、そこだけ極端に明るくなる。箱の口の少し下に置く
        innerLight.position = SCNVector3(0, Float(boxH / 2 - 0.1), 0)
        root.addChildNode(innerLight)

        // 最初は上の外に置いておく
        root.position = SCNVector3(0, 5, 0)
        root.eulerAngles.y = -0.9
        root.scale = SCNVector3(0.75, 0.75, 0.75)
    }

    private static func band(width: CGFloat, height: CGFloat, length: CGFloat, _ m: SCNMaterial) -> SCNNode {
        let g = SCNBox(width: width, height: height, length: length, chamferRadius: 0.012)
        g.materials = [m]
        let n = SCNNode(geometry: g)
        n.castsShadow = true
        return n
    }

    /// ちょう結び：輪を2つ外向きに傾け、真ん中に結び目
    private static func bow(_ m: SCNMaterial) -> SCNNode {
        let bow = SCNNode()
        for side: Float in [-1, 1] {
            let ring = SCNTorus(ringRadius: 0.24, pipeRadius: 0.07)
            ring.materials = [m]
            let loop = SCNNode(geometry: ring)
            loop.scale = SCNVector3(1, 1, 0.62)
            loop.eulerAngles = SCNVector3(Float.pi / 2, 0, side * 0.55)
            loop.position = SCNVector3(side * 0.24, 0.17, 0)
            bow.addChildNode(loop)
        }
        let knot = SCNNode(geometry: SCNSphere(radius: 0.11))
        knot.geometry?.materials = [m]
        knot.position.y = 0.09
        knot.scale = SCNVector3(1, 0.85, 1)
        bow.addChildNode(knot)
        return bow
    }

    /// 包み紙：紫のグラデーションに水玉と小さな音符
    private static func paperMaterial() -> SCNMaterial {
        let size = CGSize(width: 512, height: 512)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(red: 0.73, green: 0.58, blue: 0.93, alpha: 1).cgColor,
                          UIColor(red: 0.58, green: 0.42, blue: 0.85, alpha: 1).cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            UIColor(white: 1, alpha: 0.22).setFill()
            let step: CGFloat = 64
            for row in 0..<9 {
                for col in 0..<9 {
                    let x = CGFloat(col) * step + (row.isMultiple(of: 2) ? 0 : step / 2)
                    let y = CGFloat(row) * step
                    cg.fillEllipse(in: CGRect(x: x - 9, y: y - 9, width: 18, height: 18))
                }
            }
            let note = UIImage(systemName: "music.note",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .bold))?
                .withTintColor(UIColor(red: 1, green: 0.85, blue: 0.55, alpha: 0.55), renderingMode: .alwaysOriginal)
            for (x, y) in [(96.0, 96.0), (352.0, 160.0), (224.0, 352.0), (448.0, 416.0), (64.0, 400.0)] {
                note?.draw(at: CGPoint(x: x, y: y))
            }
        }
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = img
        m.roughness.contents = 0.42
        m.metalness.contents = 0.05
        return m
    }

    /// リボン：つやのある金
    private static func ribbonMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(red: 1.0, green: 0.80, blue: 0.42, alpha: 1)
        m.roughness.contents = 0.32
        m.metalness.contents = 0.7
        m.emission.contents = UIColor(red: 0.25, green: 0.16, blue: 0.02, alpha: 1)
        return m
    }

    // MARK: 動き

    /// 上から落ちてきて、弾んで、ゆっくり回る
    func playIntro() {
        let drop = SCNAction.group([
            .move(to: SCNVector3(0, 0, 0), duration: 0.6),
            .rotateTo(x: 0, y: 0.35, z: 0, duration: 0.6, usesShortestUnitArc: true),
            .scale(to: 1, duration: 0.6),
        ])
        drop.timingMode = .easeIn
        root.runAction(.sequence([drop, Self.squash(amount: 0.16, duration: 0.45), idle()]), forKey: "intro")
    }

    private func idle() -> SCNAction {
        let up = SCNAction.group([.moveBy(x: 0, y: 0.08, z: 0, duration: 1.1), .rotateBy(x: 0, y: 0.28, z: 0, duration: 1.1)])
        up.timingMode = .easeInEaseOut
        let down = SCNAction.group([.moveBy(x: 0, y: -0.08, z: 0, duration: 1.1), .rotateBy(x: 0, y: -0.28, z: 0, duration: 1.1)])
        down.timingMode = .easeInEaseOut
        return .repeatForever(.sequence([up, down]))
    }

    /// 震えてためを作り、ふたを飛ばして、光と紙吹雪を出す
    func open() {
        root.removeAllActions()
        root.runAction(.rotateTo(x: 0, y: 0.35, z: 0, duration: 0.08, usesShortestUnitArc: true))

        // 震え（だんだん強く）と、ふくらみ
        let angles: [CGFloat] = [0.05, -0.07, 0.09, -0.11, 0.13, -0.13, 0]
        let shake = SCNAction.sequence(angles.map { .rotateTo(x: 0, y: 0.35, z: $0, duration: 0.06, usesShortestUnitArc: true) })
        let swell = SCNAction.customAction(duration: 0.42) { node, t in
            let p = Float(t / 0.42)
            node.scale = SCNVector3(1 + 0.08 * p, 1 - 0.06 * p, 1 + 0.08 * p)
        }
        let pop = SCNAction.run { [weak self] _ in
            Task { @MainActor in self?.pop() }
        }
        root.runAction(.sequence([.group([shake, swell]), pop, Self.squash(amount: 0.12, duration: 0.5, from: 1.08), slowSpin()]))
    }

    private func pop() {
        // ふたが回りながら飛んで消える
        let fly = SCNAction.group([
            .moveBy(x: 2.4, y: 2.8, z: -1.6, duration: 1.0),
            .rotateBy(x: -2.6, y: 1.4, z: 1.8, duration: 1.0),
            .sequence([.wait(duration: 0.45), .fadeOut(duration: 0.55)]),
        ])
        fly.timingMode = .easeOut
        lid.runAction(fly)

        // 箱の中から光
        innerLight.runAction(.customAction(duration: 1.4) { node, t in
            let p = Double(t) / 1.4
            let rise: Double = 1500 * (p / 0.12)
            let decay: Double = 1500 - 1100 * min(1, (p - 0.12) / 0.88)
            node.light?.intensity = CGFloat(p < 0.12 ? rise : decay)
        })
        let glow = SCNNode(geometry: SCNSphere(radius: 0.5))
        let gm = SCNMaterial()
        gm.lightingModel = .constant
        gm.diffuse.contents = UIColor(red: 0.8, green: 0.66, blue: 0.42, alpha: 1)
        gm.emission.contents = UIColor(red: 0.7, green: 0.55, blue: 0.3, alpha: 1)
        gm.blendMode = .add
        gm.writesToDepthBuffer = false
        glow.geometry?.materials = [gm]
        glow.scale = SCNVector3(0.2, 0.2, 0.2)
        mouth.addChildNode(glow)
        glow.runAction(.sequence([
            .group([.scale(to: 2.2, duration: 0.6), .sequence([.wait(duration: 0.1), .fadeOut(duration: 0.5)])]),
            .removeFromParentNode(),
        ]))

        // 紙吹雪・きらめき・音符
        let palette: [UIColor] = [
            UIColor(red: 1.00, green: 0.56, blue: 0.71, alpha: 1),   // ピンク
            UIColor(red: 1.00, green: 0.82, blue: 0.40, alpha: 1),   // 金
            UIColor(red: 0.70, green: 0.56, blue: 0.98, alpha: 1),   // ラベンダー
            UIColor(red: 0.50, green: 0.86, blue: 0.75, alpha: 1),   // ミント
            UIColor(red: 0.55, green: 0.80, blue: 1.00, alpha: 1),   // 空色
        ]
        for c in palette { mouth.addParticleSystem(Particles.confetti(color: c)) }
        mouth.addParticleSystem(Particles.sparkles())
        mouth.addParticleSystem(Particles.notesBurst())
        mouth.addParticleSystem(Particles.notesStream())   // 開いたあとも、ゆっくり音符が昇る
    }

    private func slowSpin() -> SCNAction {
        let spin = SCNAction.rotateBy(x: 0, y: 0.35, z: 0, duration: 2.4)
        spin.timingMode = .easeInEaseOut
        let back = SCNAction.rotateBy(x: 0, y: -0.35, z: 0, duration: 2.4)
        back.timingMode = .easeInEaseOut
        return .repeatForever(.sequence([spin, back]))
    }

    /// 縦につぶれて横にふくらみ、弾んで元に戻る
    private static func squash(amount: Float, duration: TimeInterval, from start: Float = 1) -> SCNAction {
        SCNAction.customAction(duration: duration) { node, t in
            let p = Float(t / CGFloat(duration))
            let wobble = amount * sin(p * .pi * 2.5) * (1 - p)
            let base = start + (1 - start) * p
            node.scale = SCNVector3(base + wobble, base - wobble, base + wobble)
        }
    }
}

// MARK: - 粒

private enum Particles {
    static let confettiImage: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 20)).image { _ in
        UIColor.white.setFill()
        UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 12, height: 20), cornerRadius: 3).fill()
    }

    static let sparkImage: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { ctx in
        let colors = [UIColor.white.cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                         endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
    }

    static let noteImage: UIImage = {
        let cfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .black)
        let symbol = UIImage(systemName: "music.note", withConfiguration: cfg)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        return UIGraphicsImageRenderer(size: CGSize(width: 48, height: 48)).image { _ in
            symbol?.draw(in: CGRect(x: 6, y: 2, width: 36, height: 44))
        }
    }()

    private static func fade(_ keys: [NSNumber] = [0, 0.75, 1], _ values: [Float] = [1, 1, 0]) -> SCNParticlePropertyController {
        let a = CAKeyframeAnimation()
        a.values = values
        a.keyTimes = keys
        return SCNParticlePropertyController(animation: a)
    }

    static func confetti(color: UIColor) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = confettiImage
        p.particleColor = color
        p.particleColorVariation = SCNVector4(0.02, 0.08, 0.08, 0)
        p.birthRate = 300
        p.emissionDuration = 0.18
        p.loops = false
        p.particleLifeSpan = 2.6
        p.particleLifeSpanVariation = 0.7
        p.emitterShape = SCNSphere(radius: 0.35)
        p.birthLocation = .volume
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 58
        p.particleVelocity = 5.2
        p.particleVelocityVariation = 2.0
        p.acceleration = SCNVector3(0, -5.8, 0)
        p.dampingFactor = 0.8
        p.particleSize = 0.07
        p.particleSizeVariation = 0.03
        p.particleAngleVariation = 180
        p.particleAngularVelocity = 420
        p.particleAngularVelocityVariation = 720
        p.orientationMode = .free
        p.isLightingEnabled = false
        p.propertyControllers = [.opacity: fade()]
        return p
    }

    static func sparkles() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = sparkImage
        // 足し合わせで光るので、数と大きさを絞る（多いと重なって白い雲になる）
        p.particleColor = UIColor(red: 1, green: 0.78, blue: 0.38, alpha: 1)
        p.birthRate = 120
        p.emissionDuration = 0.25
        p.loops = false
        p.particleLifeSpan = 0.9
        p.particleLifeSpanVariation = 0.3
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 75
        p.particleVelocity = 4.6
        p.particleVelocityVariation = 2
        p.dampingFactor = 1.6
        p.particleSize = 0.07
        p.particleSizeVariation = 0.04
        p.blendMode = .additive
        p.isLightingEnabled = false
        p.propertyControllers = [.opacity: fade([0, 0.4, 1], [1, 0.9, 0])]
        return p
    }

    static func notesBurst() -> SCNParticleSystem {
        let p = notes()
        p.birthRate = 60
        p.emissionDuration = 0.4
        p.loops = false
        p.particleVelocity = 3.4
        return p
    }

    static func notesStream() -> SCNParticleSystem {
        let p = notes()
        p.birthRate = 5
        p.loops = true
        p.warmupDuration = 0
        p.particleVelocity = 1.4
        return p
    }

    private static func notes() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = noteImage
        p.particleColor = UIColor(red: 1, green: 0.78, blue: 0.9, alpha: 1)
        p.particleColorVariation = SCNVector4(0.25, 0.3, 0.1, 0)
        p.particleLifeSpan = 2.6
        p.particleLifeSpanVariation = 0.6
        p.emitterShape = SCNSphere(radius: 0.4)
        p.birthLocation = .volume
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 35
        p.particleVelocityVariation = 0.8
        p.acceleration = SCNVector3(0, 0.6, 0)
        p.particleSize = 0.16
        p.particleSizeVariation = 0.06
        p.particleAngleVariation = 25
        p.isLightingEnabled = false
        p.propertyControllers = [.opacity: fade([0, 0.15, 0.7, 1], [0, 1, 1, 0])]
        return p
    }
}
