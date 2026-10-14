import SwiftUI
import VisionKit

// ─────────────────────────────────────────────────────────────
//  QR 名刺（StyleCare の InviteScreen と同じ作り）
//
//  いちばん多いのは「目の前にいる人を誘う」場面。共有シートで LINE を選んで…
//  より、QR を出して相手にカメラを向けてもらうほうが早い。
//  写真・表示名・ユーザーID・QR を1枚の札にまとめて画面の真ん中に置く。
//
//  読み取る側も同じ画面に置く（右上のカメラ）。**見せる側と読む側が別の場所に
//  あると、2人で1つずつ違う画面を探すことになる。** どちらが出しても成り立つ形。
// ─────────────────────────────────────────────────────────────

struct InviteCardView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var scanning = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "B79CFF"), Color(hex: "7248E0"), Color(hex: "3D2F60")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 0)
                card
                Text("相手のカメラで読み取ってもらうと、フレンド申請が届きます")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                if let url = vm.myInviteURL {
                    ShareLink(item: url, message: Text("StreetMelody でフレンドになろう！ ユーザーID：@\(vm.myHandle ?? "")")) {
                        Label("リンクで送る", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .mlGlass(in: Capsule(), interactive: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.goBack() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                }
                .accessibilityLabel("閉じる")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { scanning = true } label: {
                    Image(systemName: "camera.viewfinder").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                }
                .accessibilityLabel("相手のQRを読む")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $scanning) {
            QRScanView { url in
                scanning = false
                _ = vm.openInvite(url: url)
            } onClose: { scanning = false }
        }
    }

    private var card: some View {
        VStack(spacing: 14) {
            UserAvatar(image: vm.avatarUIImage(), name: vm.profile.displayName ?? "", size: 72)
            VStack(spacing: 4) {
                Text(vm.profile.displayName ?? "名前未設定").font(.system(size: 20, weight: .black)).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(vm.myHandle.map { "@\($0)" } ?? "@----").font(.system(size: 13, weight: .heavy)).foregroundStyle(Color(hex: "7248E0"))
                    CopyIdButton(handle: vm.myHandle, showsLabel: false)
                }
            }
            if let url = vm.myInviteURL {
                QRCodeImage(text: url.absoluteString)
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "E0D8F7")))
                    .frame(maxWidth: 240)
            } else {
                // ID が無いと QR を作れない
                VStack(spacing: 10) {
                    Image(systemName: "qrcode").font(.system(size: 40)).foregroundStyle(Color(hex: "B8ACD6"))
                    Text("ユーザーIDを決めると QR が出ます").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "7B6F8A"))
                    Button("ユーザーIDを決める") { vm.showProfileEdit = true }
                        .font(.system(size: 13, weight: .black)).foregroundStyle(Color(hex: "7248E0"))
                }
                .frame(height: 220)
            }
            Text("StreetMelody").font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "B8ACD6"))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }
}

// MARK: - 相手の QR を読む（StyleCare の ScanInviteScreen と同じ考え）
//
//  自分たちの招待リンク（com.streetmelody.app://invite/<ID>）だけを受ける。
//  他のアプリの QR を読んでも何も起きない ―― 関係のない QR で
//  「見つかりませんでした」を出さないように。
//  読み取ったら相手を見せる札を開く。**申請はそこで本人が押す**（自動では送らない）。

struct QRScanView: View {
    let onFound: (URL) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                QRScannerRepresentable(onFound: onFound).ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill").font(.system(size: 36)).foregroundStyle(.white.opacity(0.6))
                    Text("この端末ではカメラで QR を読めません")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    Text("（シミュレーターでは使えません。実機で試してください）")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxHeight: .infinity)
            }
            HStack {
                Text("相手の QR を枠に入れてください").font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).mlGlass(in: Circle(), interactive: true)
                }
                .accessibilityLabel("閉じる")
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
    }

    /// 自分たちの招待リンクか（他アプリの QR は受けない）
    static func inviteURL(from payload: String) -> URL? {
        guard let url = URL(string: payload.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "com.streetmelody.app", url.host == "invite",
              !url.lastPathComponent.isEmpty, url.lastPathComponent != "/" else { return nil }
        return url
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onFound: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                           qualityLevel: .balanced,
                                           isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onFound: (URL) -> Void
        private var done = false
        init(onFound: @escaping (URL) -> Void) { self.onFound = onFound }

        func dataScanner(_ scanner: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for item in items {
                if case .barcode(let b) = item, let s = b.payloadStringValue, let url = QRScanView.inviteURL(from: s) {
                    done = true
                    scanner.stopScanning()
                    onFound(url)
                    return
                }
            }
        }
    }
}
