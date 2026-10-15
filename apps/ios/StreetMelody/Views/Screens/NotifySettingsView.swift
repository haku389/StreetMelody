import SwiftUI

struct NotifySettingsView: View {
    @EnvironmentObject var vm: AppViewModel

    private let digestTimes = ["09:00", "12:00", "20:00"]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                navHeader
                immediateRow
                encounterRow
                missionRow
                digestSection
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
                Text("通知設定").font(.system(size: 20, weight: .black)).foregroundStyle(.primary)
                Text("どのタイミングで通知するかを設定します")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            Spacer()
        }
        .padding(.bottom, 18)
    }

    private var immediateRow: some View {
        settingRow(
            icon: "🔔",
            title: "即時通知",
            subtitle: "すれちがいがあったとき、すぐに通知します",
            isOn: $vm.notifyImmediate
        )
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    private var encounterRow: some View {
        settingRow(
            icon: "👥",
            title: "出会い通知",
            subtitle: "新しいすれちがいを検知したときに通知します",
            isOn: $vm.notifyEncounter
        )
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    private var missionRow: some View {
        settingRow(
            icon: "🎯",
            title: "ミッション通知",
            subtitle: "デイリーミッションが達成できるタイミングで通知します",
            isOn: $vm.notifyMission
        )
        .padding(16).mlCard()
        .padding(.bottom, 14)
    }

    private var digestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingRow(
                icon: "📋",
                title: "まとめ通知",
                subtitle: "1日のすれちがいまとめを指定時刻に通知します",
                isOn: $vm.notifyDigest
            )

            if vm.notifyDigest {
                Divider().background(Color(hex: "E0D8F7"))

                VStack(alignment: .leading, spacing: 8) {
                    Text("通知時刻").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "7B6F8A"))
                    HStack(spacing: 8) {
                        ForEach(digestTimes, id: \.self) { time in
                            Button {
                                vm.notifyDigestTime = time
                            } label: {
                                Text(time)
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(vm.notifyDigestTime == time ? .white : Color(hex: "7B6F8A"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        vm.notifyDigestTime == time ? Color(hex: "7248E0") : Color(hex: "EDE8FF"),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(vm.notifyDigestTime == time ? Color(hex: "7248E0") : Color(hex: "E0D8F7")))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16).mlCard()
    }

    private func settingRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(icon).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                Text(subtitle).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .tint(Color(hex: "7248E0"))
                .labelsHidden()
        }
    }
}
