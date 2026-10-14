import SwiftUI
import UIKit
import PhotosUI

struct MyPageView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var showAccountSheet = false
    @State private var showManualShare = false
    @State private var manualTitle = ""
    @State private var manualArtist = ""
    @State private var avatarItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader
                melodyButtons
                oshiSection
                musicServicesSection
                sharedFeedSection
                accountSection
                settingsMenu
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
        .task { await vm.loadSharedFeed(); await vm.loadSocialGraph() }
        .sheet(isPresented: $showManualShare) { manualShareSheet }
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

    // MARK: - Profile header

    private var profileHeader: some View {
        let lv = vm.levelInfo()
        return VStack(spacing: 14) {
            HStack(spacing: 14) {
                // アイコン（タップで変更）
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let img = vm.avatarUIImage() {
                                Image(uiImage: img).resizable().scaledToFill()
                            } else {
                                Circle().fill(Color(hex: "EDE8FF")).overlay(Text("🎵").font(.title))
                            }
                        }
                        .frame(width: 64, height: 64).clipShape(Circle())
                        Circle().fill(Color(hex: "7248E0")).frame(width: 22, height: 22)
                            .overlay(Image(systemName: "camera.fill").font(.system(size: 9, weight: .black)).foregroundStyle(.white))
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(vm.profile.displayName ?? vm.user?.name ?? "StreetMelodyユーザー")
                            .font(.system(size: 16, weight: .black)).foregroundStyle(.primary)
                        if vm.premium {
                            Text("⭐ プレミアム")
                                .font(.system(size: 9, weight: .black)).foregroundStyle(Color(hex: "b8860b"))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color(hex: "ffd700").opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "ffd700").opacity(0.4)))
                        }
                    }
                    if let h = vm.profile.handle, !h.isEmpty {
                        Text("@\(h)").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7248E0"))
                    }
                    Text("Lv.\(lv.level) · メロディコイン \(formatNumber(vm.coins))")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                    ProgressBarView(value: Double(lv.current) / Double(max(lv.next, 1))).frame(height: 6)
                    Text("次のレベルまで あと\(lv.next - lv.current) EXP")
                        .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "B8ACD6"))
                }
                Spacer()
                GlassIconButton(systemName: "pencil", accessibilityLabel: "プロフィールを編集") {
                    vm.showProfileEdit = true
                }
            }

            // フレンド / フォロー中 / フォロワー（タップで一覧） ＋ フレンド追加
            HStack(spacing: 0) {
                countButton(vm.social.filter { $0.isFriend }.count, "フレンド", .friends)
                countButton(vm.social.filter { $0.following }.count, "フォロー中", .following)
                countButton(vm.social.filter { $0.followedBy }.count, "フォロワー", .followers)
                Button { vm.navigate(to: .socialList(.friends)) } label: {
                    HStack(spacing: 5) { Image(systemName: "person.badge.plus"); Text("フレンドを追加") }
                        .font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "7248E0"))
                        .lineLimit(1).fixedSize()   // 狭い端末でも折り返さない（件数側が縮む）
                        .padding(.horizontal, 12).padding(.vertical, 12)
                        .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
            .padding(10)
            .background(Color(hex: "F8F5FF"), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "EDE8FF")))
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    private func countButton(_ n: Int, _ label: String, _ tab: SocialTab) -> some View {
        Button { vm.navigate(to: .socialList(tab)) } label: {
            VStack(spacing: 3) {
                Text("\(n)").font(.system(size: 18, weight: .black)).foregroundStyle(.primary)
                Text(label).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // マイメロディ試聴 ＋ メロディミックス（横並び）
    private var melodyButtons: some View {
        HStack(spacing: 12) {
            Button { vm.playMyMelody() } label: {
                VStack(spacing: 6) {
                    Image(systemName: "music.note").font(.system(size: 18, weight: .black))
                    Text("マイメロディを試聴").font(.system(size: 12, weight: .black))
                    Text("音色: \(vm.myTimbreName)").font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
                .foregroundStyle(Color(hex: "7248E0"))
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            Button { vm.navigate(to: .melodyMix) } label: {
                VStack(spacing: 6) {
                    Image(systemName: "wand.and.stars").font(.system(size: 18, weight: .black))
                    Text("メロディミックスを試す").font(.system(size: 12, weight: .black))
                    Text(" ").font(.system(size: 9, weight: .heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(LinearGradient(colors: [Color(hex: "9670F0"), Color(hex: "7248E0")], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 14)
    }

    // MARK: - Account section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("アカウント")
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: "7248E0"))
                    .frame(width: 40, height: 40)
                    .overlay(Text(vm.isGuestAccount ? "👤" : "🎵").font(.system(size: 16)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.isGuestAccount ? "ゲストアカウント" : "連携済み")
                        .font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                    Text(vm.isGuestAccount ? "この端末のみ · 連携で機種変更に対応"
                                           : (vm.accountEmail ?? "メール連携済み"))
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
            }
            if vm.isGuestAccount {
                Button { showAccountSheet = true } label: {
                    Text("アカウントを連携 / ログイン").buttonLabel(.primary)
                }
            } else {
                Button { Task { await vm.signOutAccount() } } label: {
                    Text("ログアウト").buttonLabel(.secondary)
                }
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
        .sheet(isPresented: $showAccountSheet) { AccountLinkView().environmentObject(vm) }
    }

    // MARK: - Oshi section

    private var oshiSection: some View {
        let limit = vm.premium ? 5 : 3
        let oshiTracks = vm.oshiTrackIds.compactMap { vm.track(for: $0) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeading("推し曲設定")
                Spacer()
                Text("\(oshiTracks.count) / \(limit)曲")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            Text("推し曲を設定すると、すれちがいの相手にあなたの推し曲が届きます（解放済みの曲から選べます）")
                .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))

            if oshiTracks.isEmpty {
                Text("まだ推し曲が設定されていません")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            } else {
                ForEach(oshiTracks) { track in
                    HStack(spacing: 10) {
                        ArtBlockView(track: track, cornerRadius: 10).frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title ?? "—").font(.system(size: 12, weight: .black)).lineLimit(1).foregroundStyle(.primary)
                            Text(track.displayArtist).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        }
                        Spacer()
                        Button { vm.toggleOshi(trackId: track.id) } label: {
                            Text("✕").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "B8ACD6"))
                                .frame(width: 26, height: 26)
                                .background(Color(hex: "EDE8FF"), in: Circle())
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color(hex: "7248E0").opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "E0D8F7")))
                }
            }

            if oshiTracks.count < limit {
                VStack(alignment: .leading, spacing: 8) {
                    Text("解放済みの曲から選択")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                    let available = vm.unlockedTrackIds.filter { !vm.oshiTrackIds.contains($0) }.compactMap { vm.track(for: $0) }
                    if available.isEmpty {
                        Text("解放済みの曲がありません")
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(available) { track in
                                Button("+ \(track.title ?? "—")") { vm.toggleOshi(trackId: track.id) }
                                    .font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "7248E0"))
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Color(hex: "7248E0").opacity(0.1), in: Capsule())
                                    .overlay(Capsule().stroke(Color(hex: "7248E0").opacity(0.3)))
                            }
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    // MARK: - Music services

    private var musicServicesSection: some View {
        let services = [("spotify", "🎵", "Spotify"), ("appleMusic", "🎵", "Apple Music"), ("youtubeMusic", "▶", "YouTube Music")]

        return VStack(alignment: .leading, spacing: 0) {
            sectionHeading("音楽サービス連携").padding(.bottom, 10)
            ForEach(Array(services.enumerated()), id: \.offset) { i, sv in
                HStack {
                    let connected = vm.linkedServices[sv.0] ?? false
                    HStack(spacing: 6) {
                        Text(sv.1)
                        Text(sv.2).font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                        if connected {
                            Text("✓ 連携中").font(.system(size: 9, weight: .black)).foregroundStyle(Color(hex: "1A9E6E"))
                        }
                    }
                    Spacer()
                    Button(connected ? "解除" : "連携する") { vm.toggleService(sv.0) }
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(connected ? Color(hex: "7B6F8A") : .white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(connected ? Color(hex: "EDE8FF") : Color(hex: "7248E0"), in: RoundedRectangle(cornerRadius: 12))
                        .disabled(vm.nowPlayingBusy)
                }
                .padding(.vertical, 12)
                if i < services.count - 1 {
                    Divider().background(Color(hex: "E0D8F7"))
                }
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    // MARK: - Shared feed（みんなの今聴いてる曲）

    private var sharedFeedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                sectionHeading("みんなの今聴いてる曲")
                Spacer()
                Button("手動で共有") { manualTitle = ""; manualArtist = ""; showManualShare = true }
                    .font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "7248E0"))
                Button("更新") { Task { await vm.loadSharedFeed() } }
                    .font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "7248E0"))
            }
            .padding(.bottom, 10)

            if vm.sharedFeed.isEmpty {
                Text("まだ共有されている曲はありません。")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            } else {
                ForEach(Array(vm.sharedFeed.enumerated()), id: \.element.id) { i, np in
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: "EDE8FF")).frame(width: 30, height: 30)
                            .overlay(Text("🎵").font(.system(size: 13)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(np.trackTitle).font(.system(size: 12, weight: .black)).foregroundStyle(.primary).lineLimit(1)
                            Text("\(np.displayName ?? "メロディアン") · \(np.serviceKind.displayName)")
                                .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A")).lineLimit(1)
                        }
                        Spacer()
                        if np.visibility == "friends" {
                            Text("フレンド").font(.system(size: 8, weight: .black)).foregroundStyle(Color(hex: "1A9E6E"))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Color(hex: "1A9E6E").opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.vertical, 8)
                    if i < vm.sharedFeed.count - 1 { Divider().background(Color(hex: "E0D8F7")) }
                }
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
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

    // MARK: - Settings menu

    private var settingsMenu: some View {
        let bgLabel = vm.bgScanEnabled ? "オン · \(vm.bgScanMode == "normal" ? "標準" : "省電力")スキャン" : "オフ"
        let items: [(label: String, sub: String, screen: Screen?)] = [
            ("通知設定",              "即時通知・まとめ通知の設定",              .notifySettings),
            ("バックグラウンド検知",    bgLabel,                               .bgSettings),
            ("プレミアムプラン",        vm.premium ? "⭐ 加入中" : "広告非表示・推し曲5曲・エリアランキング", .premium),
            ("ショップ",               "メロディコイン · アバター装飾\(vm.hintTickets > 0 ? " · 🎟️×\(vm.hintTickets)" : "")", .shop),
            ("ヘルプ",                 "",                                     nil),
            ("利用規約 / プライバシーポリシー", "",                              nil),
        ]

        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                Button {
                    if let screen = item.screen { vm.navigate(to: screen) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label).font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                            if !item.sub.isEmpty {
                                Text(item.sub).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                            }
                        }
                        Spacer()
                        Text("›").font(.system(size: 18, weight: .heavy)).foregroundStyle(Color(hex: "B8ACD6"))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                if i < items.count - 1 {
                    Divider().background(Color(hex: "E0D8F7"))
                }
            }
        }
        .background(Color(hex: "FFFFFF"), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: "E0D8F7")))
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
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
