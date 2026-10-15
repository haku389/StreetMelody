import SwiftUI

struct BgSettingsView: View {
    @EnvironmentObject var vm: AppViewModel

    private let modes = [("fast", "高感度スキャン", "より多くのすれちがいを検知（電池消費大）"),
                         ("normal", "標準スキャン", "バランス重視（推奨）"),
                         ("eco", "省電力スキャン", "電池消費を最小限に（見逃しが増えることがあります）")]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                navHeader
                enableToggle
                if vm.bgScanEnabled { modeSelector; nightPauseToggle }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(MLBackground())
        .navigationBarBackButtonHidden(true)
        .mlNavBarBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color(hex: "7248E0"))
                }
            }
        }
    }

    private var navHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("バックグラウンド検知").font(.system(size: 20, weight: .black)).foregroundStyle(.primary)
                Text("アプリを閉じていてもすれちがいを検知します")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            Spacer()
        }
        .padding(.bottom, 18)
    }

    private var enableToggle: some View {
        HStack(spacing: 12) {
            Text("📡").font(.system(size: 22))
            VStack(alignment: .leading, spacing: 3) {
                Text("バックグラウンド検知").font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                Text("オフにするとすれちがいが検知されなくなります")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            Spacer()
            Toggle("", isOn: $vm.bgScanEnabled).tint(Color(hex: "7248E0")).labelsHidden()
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("スキャンモード").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
            ForEach(modes, id: \.0) { id, label, sub in
                Button {
                    vm.bgScanMode = id
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(vm.bgScanMode == id ? Color(hex: "7248E0") : Color(hex: "E0D8F7"))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle().fill(.white).frame(width: 8, height: 8)
                                    .opacity(vm.bgScanMode == id ? 1 : 0)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label).font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                            Text(sub).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(vm.bgScanMode == id ? Color(hex: "7248E0").opacity(0.08) : Color(hex: "FFFFFF"),
                                in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                        vm.bgScanMode == id ? Color(hex: "7248E0").opacity(0.35) : Color(hex: "E0D8F7")))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    private var nightPauseToggle: some View {
        HStack(spacing: 12) {
            Text("🌙").font(.system(size: 22))
            VStack(alignment: .leading, spacing: 3) {
                Text("夜間は検知しない").font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                Text("22:00〜7:00 はBluetoothスキャンを停止します")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            Spacer()
            Toggle("", isOn: $vm.bgNightPause).tint(Color(hex: "7248E0")).labelsHidden()
        }
        .padding(16).mlCard()
    }
}
