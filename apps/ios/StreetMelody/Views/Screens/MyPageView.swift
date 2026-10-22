import SwiftUI
import UIKit
import PhotosUI

// ─────────────────────────────────────────────────────────────
//  マイページ（StyleCare の MyPageScreen と同じ並び）
//
//  プロフィールのカード（写真・名前・ID・フレンド数・QR）のあと、
//  カードの外に小見出しを置き、メニューは1項目1枚のカードで並べる。
//  フレンドもメニューの1項目。申請が届いているときは数を出し、押すと「届いた申請」から開く。
//  右上は StyleCare と同じく「フレンドを追加」と歯車（設定のシート）。名前・ID・ひとことは
//  プロフィールのカードから直す。アカウント・ログイン方法・規約・ログアウトは設定へ移した。
// ─────────────────────────────────────────────────────────────

struct MyPageView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showSettings = false
    @State private var showManualShare = false
    @State private var manualTitle = ""
    @State private var manualArtist = ""
    @State private var avatarItem: PhotosPickerItem?

    var body: some View {
        MLTabScreen {
            HStack {
                MLTabTitle(title: "マイページ", showsSymbol: false)
                GlassIconButton(systemName: "person.badge.plus", accessibilityLabel: "フレンドを追加") {
                    vm.navigate(to: .friendAdd)
                }
                GlassIconButton(systemName: "gearshape", accessibilityLabel: "設定") {
                    showSettings = true
                }
            }
        } content: {
            VStack(spacing: 0) {
                profileCard
                HStack(spacing: 10) {
                    profileMetric("推し曲", value: "\(vm.oshiTrackIds.count)曲", tint: MLPalette.rose)
                    profileMetric("完成した曲", value: "\(vm.tracks.values.filter { $0.isComplete }.count)曲", tint: MLPalette.lilac)
                    profileMetric("フレンド", value: "\(vm.friendsOnly.count)人", tint: MLPalette.honey)
                }.padding(.top, 14)
                MLSectionTitle(text: "マイメロディ")
                melodyButtons
                MLSectionTitle(text: "推し曲")
                oshiSection
                MLSectionTitle(text: "メニュー")
                menuCards
                MLSectionTitle(text: "音楽サービス連携")
                musicServicesSection
                sharedFeedHeader
                sharedFeedSection
                MLSectionTitle(text: "契約")
                MLMenuCard(icon: "crown.fill", tint: Color(hex: "D99A1E"), title: "プレミアムプラン",
                           desc: vm.premium ? "加入中" : "広告非表示・推し曲5曲・エリアランキング") {
                    vm.navigate(to: .premium)
                }
            }
        }
        .task { await vm.loadSharedFeed(); await vm.loadFriends() }
        .sheet(isPresented: $showManualShare) { manualShareSheet }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(vm) }
        .onChange(of: avatarItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    vm.setAvatar(ui)
                }
                avatarItem = nil
            }
        }
    }

    private func profileMetric(_ label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 9)).foregroundStyle(MLPalette.muted)
            Text(value).font(.system(size: 21, weight: .bold)).foregroundStyle(MLPalette.ink)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14).mlInset(radius: 18, tint: tint)
    }

    // MARK: - プロフィール（写真・名前・ID・フレンド数・QR）

    private var profileCard: some View {
        let lv = vm.levelInfo()
        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                // 写真（タップで変更）
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    UserAvatar(image: vm.avatarUIImage(), name: vm.profile.displayName ?? "", size: 58)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill").font(.system(size: 9, weight: .black)).foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Color(hex: "A27BC8"), in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .offset(x: 3, y: 3)
                        }
                }
                .buttonStyle(MLPressButtonStyle())

                VStack(alignment: .leading, spacing: 4) {
                    // 名前とひとことは、ここで直す（自分に関する設定なので）
                    Button { vm.showProfileEdit = true } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(vm.profile.displayName ?? "名前未設定")
                                .font(.system(size: 17, weight: .black)).foregroundStyle(MLPalette.ink).lineLimit(1)
                            Text("変更").font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
                        }
                    }
                    .buttonStyle(MLPressButtonStyle())
                    // ID の横で写せるようにする（伝えるときは貼り付けるのが早い）
                    HStack(spacing: 6) {
                        Text(vm.myHandle.map { "@\($0)" } ?? "@----")
                            .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "A27BC8")).lineLimit(1)
                        CopyIdButton(handle: vm.myHandle, showsLabel: false)
                    }
                    if vm.premium {
                        Label("プレミアム", systemImage: "crown.fill")
                            .font(.system(size: 9, weight: .black)).foregroundStyle(Color(hex: "B8860B"))
                    }
                }
                Spacer(minLength: 4)

                // フレンドの数（押すと一覧）。申請が来ていれば「届いた申請」から開く
                Button { vm.navigate(to: .friends(vm.incomingRequests.isEmpty ? .list : .requests)) } label: {
                    VStack(spacing: 1) {
                        Text("\(vm.friendsOnly.count)").font(.system(size: 19, weight: .black)).foregroundStyle(MLPalette.ink)
                        Text("フレンド").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                    }
                    .overlay(alignment: .topTrailing) {
                        if !vm.incomingRequests.isEmpty { CountBadge(count: vm.incomingRequests.count).offset(x: 12, y: -8) }
                    }
                }
                .buttonStyle(MLPressButtonStyle())

                // 数の隣に増やす口を置く。増やしたくなるのは数を見たとき。
                // 絵は QR（＋だと押した先で QR が出ることが分からない）
                Button { vm.navigate(to: .inviteCard) } label: {
                    Image(systemName: "qrcode").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color(hex: "A27BC8"), in: Circle())
                }
                .buttonStyle(MLPressButtonStyle())
                .accessibilityLabel("自分の QR を見せる")
            }

            // レベルとコイン
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Lv.\(lv.level)").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
                    Spacer()
                    CoinIcon(size: 16)
                    Text("\(formatNumber(vm.coins))").font(.system(size: 12, weight: .black)).foregroundStyle(MLPalette.ink)
                }
                ProgressBarView(value: Double(lv.current) / Double(max(lv.next, 1))).frame(height: 6)
                Text("次のレベルまで あと\(lv.next - lv.current) EXP")
                    .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "B29ABC"))
            }
        }
        .padding(16).mlCard()
    }

    // MARK: - マイメロディ（試聴・ミックス）

    private var melodyButtons: some View {
        HStack(spacing: 12) {
            Button { vm.playMyMelody() } label: {
                VStack(spacing: 6) {
                    Image(systemName: "music.note").font(.system(size: 18, weight: .black))
                    Text("マイメロディを試聴").font(.system(size: 12, weight: .black))
                    Text("音色: \(vm.myTimbreName)").font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                }
                .foregroundStyle(Color(hex: "A27BC8"))
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .mlCard(radius: 18, elevation: .low)
            }
            .buttonStyle(MLPressButtonStyle())
            Button { vm.navigate(to: .melodyMix) } label: {
                VStack(spacing: 6) {
                    Image(systemName: "wand.and.stars").font(.system(size: 18, weight: .black))
                    Text("メロディミックスを試す").font(.system(size: 12, weight: .black))
                    Text(" ").font(.system(size: 9, weight: .heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(LinearGradient(colors: [Color(hex: "C3A2E4"), Color(hex: "A27BC8")], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .mlGlow()
            }
            .buttonStyle(MLPressButtonStyle())
        }
    }

    // MARK: - メニュー（1項目1枚）

    @ViewBuilder
    private var menuCards: some View {
        let friends = vm.friendsOnly.count, pending = vm.incomingRequests.count
        MLMenuCard(icon: "person.2.fill", tint: Color(hex: "3B82F6"), title: "フレンド",
                   desc: (friends > 0 ? "\(friends)人とフレンド" : "ユーザーID・QR・近くの人で追加できます")
                        + (pending > 0 ? " ・ 申請 \(pending)件" : ""),
                   badge: pending) {
            vm.navigate(to: .friends(pending > 0 ? .requests : .list))
        }
        MLMenuCard(icon: "bell.fill", tint: Color(hex: "F97316"), title: "通知",
                   desc: "即時通知・まとめ通知の設定") { vm.navigate(to: .notifySettings) }
        MLMenuCard(icon: "dot.radiowaves.left.and.right", tint: Color(hex: "A27BC8"), title: "バックグラウンド検知",
                   desc: vm.bgScanEnabled ? "オン · \(vm.bgScanMode == "normal" ? "標準" : "省電力")スキャン" : "オフ") {
            vm.navigate(to: .bgSettings)
        }
        MLMenuCard(icon: "bag.fill", tint: Color(hex: "EC4899"), title: "ショップ",
                   desc: "メロディコイン・アバター装飾" + (vm.hintTickets > 0 ? " ・ ヒントチケット \(vm.hintTickets)枚" : "")) {
            vm.navigate(to: .shop)
        }
    }

    // MARK: - Oshi section

    private var oshiSection: some View {
        let limit = vm.premium ? 5 : 3
        let oshiTracks = vm.oshiTrackIds.compactMap { vm.track(for: $0) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("すれちがいの相手に、あなたの推し曲がパズルとして届きます（解放済みの曲から選べます）")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "8D7694"))
                Spacer(minLength: 8)
                Text("\(oshiTracks.count) / \(limit)曲")
                    .font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
            }

            if oshiTracks.isEmpty {
                Text("まだ推し曲が設定されていません")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            } else {
                ForEach(oshiTracks) { track in
                    HStack(spacing: 10) {
                        ArtBlockView(track: track, cornerRadius: 8).mlThumbFrame(width: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title ?? "—").font(.system(size: 12, weight: .black)).lineLimit(1).foregroundStyle(MLPalette.ink)
                            Text(track.displayArtist).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                        }
                        Spacer()
                        Button { vm.toggleOshi(trackId: track.id) } label: {
                            Text("✕").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "B29ABC"))
                                .frame(width: 26, height: 26)
                                .background(Color(hex: "EEE0F2"), in: Circle())
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color(hex: "A27BC8").opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "EADCE7")))
                }
            }

            if oshiTracks.count < limit {
                VStack(alignment: .leading, spacing: 8) {
                    Text("解放済みの曲から選択")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                    let available = vm.unlockedTrackIds.filter { !vm.oshiTrackIds.contains($0) }.compactMap { vm.track(for: $0) }
                    if available.isEmpty {
                        Text("解放済みの曲がありません")
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(available) { track in
                                Button("+ \(track.title ?? "—")") { vm.toggleOshi(trackId: track.id) }
                                    .font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Color(hex: "A27BC8").opacity(0.1), in: Capsule())
                                    .overlay(Capsule().stroke(Color(hex: "A27BC8").opacity(0.3)))
                            }
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(16).mlCard()
    }

    // MARK: - Music services

    private var musicServicesSection: some View {
        let services = [("spotify", "Spotify"), ("appleMusic", "Apple Music"), ("youtubeMusic", "YouTube Music")]

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(services.enumerated()), id: \.offset) { i, sv in
                HStack(spacing: 12) {
                    let connected = vm.linkedServices[sv.0] ?? false
                    ServiceIcon(service: sv.0, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sv.1).font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                        if connected {
                            Label("連携中", systemImage: "checkmark").font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color(hex: "1A9E6E"))
                        }
                    }
                    Spacer()
                    Button(connected ? "解除" : "連携する") { vm.toggleService(sv.0) }
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(connected ? Color(hex: "8D7694") : .white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(connected ? Color(hex: "EEE0F2") : Color(hex: "A27BC8"), in: Capsule())
                        .disabled(vm.nowPlayingBusy)
                }
                .padding(.vertical, 10)
                if i < services.count - 1 {
                    Divider().padding(.leading, 46)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 6).mlCard()
    }

    // MARK: - みんなの今聴いてる曲

    private var sharedFeedHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("みんなの今聴いてる曲").font(.system(size: 15, weight: .black)).foregroundStyle(MLPalette.ink)
            Spacer()
            Button("手動で共有") { manualTitle = ""; manualArtist = ""; showManualShare = true }
                .font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
            Button { Task { await vm.loadSharedFeed() } } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
            }
            .accessibilityLabel("更新")
        }
        .padding(.top, 18).padding(.bottom, 8)
    }

    private var sharedFeedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if vm.sharedFeed.isEmpty {
                Text("まだ共有されている曲はありません。")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: "8D7694"))
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(vm.sharedFeed.enumerated()), id: \.element.id) { i, np in
                    HStack(spacing: 10) {
                        UserAvatar(name: np.displayName ?? "", size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(np.trackTitle).font(.system(size: 12, weight: .black)).foregroundStyle(MLPalette.ink).lineLimit(1)
                            Text("\(np.displayName ?? "メロディアン") · \(np.serviceKind.displayName)")
                                .font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "8D7694")).lineLimit(1)
                        }
                        Spacer()
                        if np.visibility == "friends" {
                            Text("フレンド").font(.system(size: 9, weight: .black)).foregroundStyle(Color(hex: "1A9E6E"))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Color(hex: "1A9E6E").opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.vertical, 8)
                    if i < vm.sharedFeed.count - 1 { Divider() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).mlCard()
    }

    private var manualShareSheet: some View {
        NavigationStack {
            Form {
                Section("今聴いている曲") {
                    TextField("曲名", text: $manualTitle)
                    TextField("アーティスト（任意）", text: $manualArtist)
                }
            }
            .navigationTitle("手動で共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { showManualShare = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("共有") {
                        let title = manualTitle, artist = manualArtist
                        showManualShare = false
                        Task { await vm.shareManualNowPlaying(title: title, artist: artist.isEmpty ? nil : artist) }
                    }
                    .disabled(manualTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(240)])
    }

}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var maxH: CGFloat = 0; var rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            x += size.width + spacing; rowH = max(rowH, size.height); maxH = y + rowH
        }
        return CGSize(width: width, height: maxH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; rowH = max(rowH, size.height)
        }
    }
}
