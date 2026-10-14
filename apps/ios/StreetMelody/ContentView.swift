import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "F5F0FF").ignoresSafeArea()

            NavigationStack(path: $vm.navigationStack) {
                tabContent
                    .navigationDestination(for: Screen.self) { screen in
                        screenView(for: screen)
                            .environmentObject(vm)
                    }
            }
            .ignoresSafeArea()

            BottomNavBar().environmentObject(vm)

            if let trackId = vm.puzzleCompleteTrackId {
                PuzzleCompleteOverlay(trackId: trackId)
                    .environmentObject(vm)
                    .zIndex(10)
            } else if let titleId = vm.pendingTitleCelebrations.first {
                TitleCelebrationOverlay(titleId: titleId)
                    .environmentObject(vm)
                    .zIndex(10)
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
                        .background(Color(hex: "3D2F60").opacity(0.95), in: Capsule())
                        .shadow(radius: 8, y: 4)
                        .padding(.bottom, 90)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: toast)
            }
        }
        .sheet(isPresented: $vm.showProfileEdit) {
            ProfileEditView().environmentObject(vm)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch vm.activeTab {
            case .home:       HomeView()
            case .melody:     MelodyView()
            case .collection: CollectionView()
            case .ranking:    RankingView()
            case .mypage:     MyPageView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
        case .friends:                    FriendsView()
        case .premium:                    PremiumView()
        case .shop:                       ShopView()
        case .notifySettings:             NotifySettingsView()
        case .bgSettings:                 BgSettingsView()
        case .mission:                    MissionView()
        case .melodyMix:                  MelodyMixView()
        case .socialList(let tab):        SocialListView(initialTab: tab)
        }
    }
}

// MARK: - Bottom Nav Bar

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
                    .foregroundStyle(vm.activeTab == tab ? Color(hex: "7248E0") : Color(hex: "B8ACD6"))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(vm.activeTab == tab ? Color(hex: "7248E0").opacity(0.12) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 17))
                }
            }
        }
        .padding(8)
        .background(Color(hex: "FFFFFF").opacity(0.97), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: "E0D8F7")))
        .shadow(color: Color(hex: "7248E0").opacity(0.10), radius: 16, y: 8)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }
}
