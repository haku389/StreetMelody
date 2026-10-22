import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            MLBackground()

            // タブバー（StyleCare と同じ切り分け）
            //  iOS 26 以降: OS 標準のタブバー。Liquid Glass は OS の実装なので、真似ずに標準を使う
            //  それ未満   : 自作の浮いたバー（ぼかし素材）
            if #available(iOS 26.0, *) {
                nativeTabs
            } else {
                NavigationStack(path: $vm.navigationStack) {
                    rootView(for: vm.activeTab)
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(for: Screen.self) { screen in
                            screenView(for: screen).environmentObject(vm)
                        }
                }
                .ignoresSafeArea()

                BottomNavBar().environmentObject(vm)
            }

            if let trackId = vm.puzzleCompleteTrackId {
                PuzzleCompleteOverlay(trackId: trackId)
                    .environmentObject(vm)
                    .zIndex(10)
            } else if let titleId = vm.pendingTitleCelebrations.first {
                TitleCelebrationOverlay(titleId: titleId)
                    .environmentObject(vm)
                    .zIndex(10)
            }

            // ログイン必須（StyleCare と同じ）。確かめ終わるまでは起動画面、
            // ログインしていなければログイン画面を全面に出す（閉じられない）
            if !vm.accountChecked {
                LaunchCover().zIndex(30).transition(.opacity)
            } else if vm.isGuestAccount || Self.previewLoginGate {
                AccountLinkView(asGate: true)
                    .environmentObject(vm)
                    .zIndex(30)
                    .transition(.opacity)
            }

            // 今日のメロディのプレゼント（1日1回。タブバーより上に出す）
            if let count = vm.melodyGiftCount {
                MelodyGiftOverlay(count: count)
                    .environmentObject(vm)
                    .zIndex(12)
                    .transition(.opacity)
            }

            if let previewId = vm.previewTrackId {
                PreviewPlayerView(trackId: previewId)
                    .environmentObject(vm)
                    .zIndex(15)
                    .transition(.opacity)
            }

            if let mvId = vm.mvTrackId {
                YouTubeMVView(trackId: mvId)
                    .environmentObject(vm)
                    .zIndex(16)
                    .transition(.opacity)
            }

            if let toast = vm.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "49335F").opacity(0.95), in: Capsule())
                        .shadow(radius: 8, y: 4)
                        .padding(.bottom, 90)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: toast)
            }
        }
        .sensoryFeedback(.selection, trigger: vm.activeTab)
        .sheet(item: $vm.invitePerson) { person in
            InvitePersonSheet(person: person).environmentObject(vm)
        }
        .sheet(isPresented: $vm.showProfileEdit) {
            ProfileEditView().environmentObject(vm)
        }
        // 読み込みが終わったとき・プロフィールの登録を閉じたとき・前面に戻ったときに、
        // 今日のメロディが届いていれば開封の演出を出す（出すかどうかは presentMelodyGiftIfNeeded が決める）
        .onChange(of: vm.isLoading) { _, loading in if !loading { presentGiftSoon() } }
        .onChange(of: vm.showProfileEdit) { _, open in if !open { presentGiftSoon() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { presentGiftSoon() } }
        .onChange(of: vm.isGuestAccount) { _, guest in if !guest { presentGiftSoon() } }
        .animation(.easeOut(duration: 0.25), value: vm.isGuestAccount)
        .animation(.easeOut(duration: 0.25), value: vm.accountChecked)
    }

    /// 開発中だけ: 起動引数 -previewLoginGate でログイン画面を出す（ログアウトせずに見た目を確かめる）
    #if DEBUG
    private static let previewLoginGate = ProcessInfo.processInfo.arguments.contains("-previewLoginGate")
    #else
    private static let previewLoginGate = false
    #endif

    /// 画面が落ち着いてから出す（ホームが描かれる前に被せない）
    private func presentGiftSoon() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            vm.presentMelodyGiftIfNeeded()
        }
    }

    // MARK: - 標準タブバー（iOS 26）

    @available(iOS 26.0, *)
    private var nativeTabs: some View {
        TabView(selection: tabSelection) {
            ForEach(Tab.allCases, id: \.self) { tab in
                SwiftUI.Tab(tab.rawValue, systemImage: tab.icon, value: tab) {
                    NavigationStack(path: path(for: tab)) {
                        rootView(for: tab)
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationDestination(for: Screen.self) { screen in
                                screenView(for: screen).environmentObject(vm)
                            }
                    }
                }
            }
        }
        .tint(MLPalette.primary)
        .toolbarBackground(MLPalette.cream, for: .tabBar)
    }

    /// タブの選択。移ったら出会いの導線を片付ける（自作バーと同じ動き）
    private var tabSelection: Binding<Tab> {
        Binding(get: { vm.activeTab },
                set: { vm.activeTab = $0; vm.clearCollectPrompts() })
    }

    /// 画面遷移の履歴は1本（vm.navigationStack）。いま選んでいるタブにだけ渡す
    private func path(for tab: Tab) -> Binding<[Screen]> {
        Binding(get: { vm.activeTab == tab ? vm.navigationStack : [] },
                set: { if vm.activeTab == tab { vm.navigationStack = $0 } })
    }

    @ViewBuilder
    private func rootView(for tab: Tab) -> some View {
        switch tab {
        case .home:       HomeView()
        case .melody:     MelodyView()
        case .collection: CollectionView()
        case .ranking:    RankingView()
        case .mypage:     MyPageView()
        }
    }

    @ViewBuilder
    private func screenView(for screen: Screen) -> some View {
        switch screen {
        case .mystery(let id):             MysteryView(trackId: id)
        case .puzzle(let id):             PuzzleView(trackId: id)
        case .pieceSelect(let encId, let candIdx): PieceSelectView(encounterId: encId, candidateIndex: candIdx)
        case .artistDetail(let id):       ArtistDetailView(artistId: id)
        case .friendDetail(let uid):      FriendDetailView(userId: uid)
        case .playlist:                   PlaylistView()
        case .premium:                    PremiumView()
        case .shop:                       ShopView()
        case .notifySettings:             NotifySettingsView()
        case .bgSettings:                 BgSettingsView()
        case .mission:                    MissionView()
        case .melodyMix:                  MelodyMixView()
        case .friends(let tab):           FriendsView(initialTab: tab)
        case .friendAdd:                  FriendAddView()
        case .inviteCard:                 InviteCardView()
        case .nearbyFriends:              NearbyFriendsView()
        }
    }
}

// MARK: - Bottom Nav Bar（iOS 25 以下の自作バー）

struct BottomNavBar: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    vm.activeTab = tab
                    vm.navigationStack = []
                    vm.clearCollectPrompts()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 9, weight: .heavy))
                    }
                    .foregroundStyle(vm.activeTab == tab ? Color.white : MLPalette.muted)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background {
                        if vm.activeTab == tab {
                            RoundedRectangle(cornerRadius: 17).fill(MLPalette.button)
                                .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(.white.opacity(0.5)))
                                .mlShadow(.low)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(MLPalette.cream, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.6)))
        .shadow(color: Color(hex: "A27BC8").opacity(0.10), radius: 16, y: 8)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }
}

/// 起動直後、ログインしているかを確かめているあいだの画面（ログイン画面を一瞬出さないため）
private struct LaunchCover: View {
    var body: some View {
        ZStack {
            MLBackground()
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(MLPalette.button)
                    .frame(width: 80, height: 80)
                    .overlay(Image(systemName: "music.note").font(.system(size: 36, weight: .black)).foregroundStyle(.white))
                    .mlGlow()
                ProgressView().tint(MLPalette.primary)
            }
        }
        .ignoresSafeArea()
    }
}
