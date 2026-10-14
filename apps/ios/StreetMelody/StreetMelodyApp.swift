import SwiftUI

@main
struct StreetMelodyApp: App {

    @StateObject private var vm = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .task { await vm.loadAll() }
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    // フレンドの招待リンク（com.streetmelody.app://invite/<ユーザーID>）
                    if vm.openInvite(url: url) { return }
                    // Spotify App Remote の認可コールバック（authorizeAndPlayURI の戻り）。
                    if url.host == "spotify-callback" {
                        MusicConnectManager.shared.handleSpotifyURL(url)
                    }
                }
        }
    }
}
