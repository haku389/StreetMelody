import SwiftUI

// MARK: - MelodyMixView（メロディミックス：2人のメロディを重ねて鳴らす）
//
// 設計書 §5：ペンタトニック固定で常に協和。ベストフレンド成立の儀式。
// 現段階は対面接続(QR/Multipeer)前のため、相手シード（将来のメロディコード）を
// 入力して「自分＋相手」のミックスを試せる。P3/P4 で実ユーザー接続に置き換える。

struct MelodyMixView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var partnerSeed = ""
    @State private var mixed = false

    private let purple = Color(hex: "7248E0")
    private let lilac = Color(hex: "EDE8FF")

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                introCard
                myMelodyCard
                partnerCard
                mixButton
                if mixed { resultCard }
            }
            .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color(hex: "F5F0FF"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.stopMelody(); vm.goBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(purple)
                }
            }
            ToolbarItem(placement: .principal) {
                Text("メロディミックス").font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
            }
        }
        .onDisappear { vm.stopMelody() }
    }

    private var introCard: some View {
        VStack(spacing: 6) {
            Text("🎶 2人のメロディを重ねよう")
                .font(.system(size: 15, weight: .black)).foregroundStyle(.primary)
            Text("お互いのテーマを混ぜて鳴らすと、2人だけのミックスが生まれます。\nこれがベストフレンド成立の儀式になります。")
                .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(18).mlCard()
    }

    private var myMelodyCard: some View {
        melodyCard(title: "あなたのメロディ",
                   subtitle: "音色: \(vm.myTimbreName)",
                   accent: purple) { vm.playMyMelody() }
    }

    private var partnerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("相手のメロディ").font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "3D2F60"))
            HStack(spacing: 8) {
                TextField("相手のコード/シード（お試し可）", text: $partnerSeed)
                    .font(.system(size: 13, weight: .heavy))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(Color(hex: "F5F0FF"), in: RoundedRectangle(cornerRadius: 12))
                Button("ランダム") { partnerSeed = UUID().uuidString }
                    .font(.system(size: 11, weight: .black)).foregroundStyle(purple)
                    .padding(.horizontal, 10).padding(.vertical, 11)
                    .background(lilac, in: RoundedRectangle(cornerRadius: 12))
            }
            Text("音色: \(vm.timbreName(forSeed: partnerSeed))")
                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            Button { vm.playPartnerMelody(seed: partnerSeed) } label: {
                Label("相手のメロディを試聴", systemImage: "music.note")
                    .font(.system(size: 12, weight: .black)).foregroundStyle(purple)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(lilac, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16).mlCard()
    }

    private var mixButton: some View {
        Button { vm.playMelodyMix(partnerSeed: partnerSeed); mixed = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                Text("メロディミックスして再生")
            }
            .font(.system(size: 16, weight: .black)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(LinearGradient(colors: [Color(hex: "9670F0"), purple], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var resultCard: some View {
        VStack(spacing: 8) {
            Text("🎉 2人のミックスが鳴りました")
                .font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
            Text("（将来：ここでお互いが合意するとベストフレンドが成立します）")
                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                .multilineTextAlignment(.center)
            Button { vm.playMelodyMix(partnerSeed: partnerSeed) } label: {
                Text("もう一度ミックスを聴く")
                    .font(.system(size: 12, weight: .black)).foregroundStyle(purple)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(lilac, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity).padding(16).mlCard()
    }

    private func melodyCard(title: String, subtitle: String, accent: Color, play: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Circle().fill(lilac).frame(width: 48, height: 48).overlay(Text("🎵").font(.title3))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                Text(subtitle).font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            }
            Spacer()
            Button(action: play) {
                Image(systemName: "play.circle.fill").font(.system(size: 30)).foregroundStyle(accent)
            }
        }
        .padding(16).mlCard()
    }
}
