import SwiftUI

struct ExchangeView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            screenHeader
            if let encounter = vm.todayEncounter {
                rewardStrip(encounter: encounter)
                candidateList(encounter: encounter)
                confirmButton(encounter: encounter)
            } else {
                ProgressView().padding(.top, 60)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
    }

    // MARK: - Header

    private var screenHeader: some View {
        HStack(spacing: 12) {
            Button { vm.activeTab = .home } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .heavy))
                    .frame(width: 42, height: 42)
                    .background(.regularMaterial, in: Circle())
                    .overlay(Circle().stroke(Color(hex: "eadff3")))
            }
            VStack(spacing: 2) {
                Text("ピースを選ぼう")
                    .font(.system(size: 15, weight: .black))
                Text("気になるピースを1つ選んでください")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(hex: "817992"))
            }
            .frame(maxWidth: .infinity)

            if let enc = vm.todayEncounter {
                timerPill(enc: enc)
            } else {
                Spacer().frame(width: 42)
            }
        }
        .padding(.bottom, 18)
    }

    private func timerPill(enc: Encounter) -> some View {
        let remaining = max(Int(enc.expiresAt.timeIntervalSinceNow), 0)
        let label = String(format: "残り時間 %02d:%02d", remaining / 60, remaining % 60)
        return Text(label)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Color(hex: "f04468"))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(hex: "fff1f4"), in: Capsule())
    }

    // MARK: - Reward strip

    private func rewardStrip(encounter: Encounter) -> some View {
        HStack(spacing: 8) {
            Text("🪙")
            Text("この交換で手に入るもの")
                .font(.system(size: 12, weight: .heavy))
            Text("メロディコイン ×\(encounter.rewardCoins)")
                .font(.system(size: 12, weight: .black))
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "eadff3")))
        .padding(.bottom, 4)
    }

    // MARK: - Candidate list

    private func candidateList(encounter: Encounter) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(encounter.candidates.enumerated()), id: \.element.id) { index, candidate in
                    candidateCard(index: index, candidate: candidate, encounter: encounter)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, -18)
    }

    private func candidateCard(index: Int, candidate: Candidate, encounter: Encounter) -> some View {
        let track = vm.track(for: candidate.trackId)
        let isSelected = vm.selectedCandidateIndex == index

        return VStack(spacing: 8) {
            ZStack(alignment: .top) {
                ArtBlockView(color: track?.color ?? "violet", cornerRadius: 16)
                    .aspectRatio(0.72, contentMode: .fit)
                // Number badge
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .black))
                    .frame(width: 28, height: 28)
                    .background(Color.white, in: Circle())
                    .shadow(radius: 4, y: 2)
                    .offset(y: -11)
                // Play dot
                Button {
                    // TODO: 試聴
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color(hex: "A27BC8"))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.94), in: Circle())
                }
                .offset(y: -50)
            }
            Text(track?.displayTitle ?? "—")
                .font(.system(size: 10, weight: .black))
                .lineLimit(1)
            Text("★".repeated(candidate.rarity))
                .font(.system(size: 9))
                .foregroundStyle(Color(hex: "ffd35b"))
        }
        .frame(width: 132)
        .padding(10)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(isSelected ? Color(hex: "A27BC8") : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, y: 4)
        .onTapGesture { vm.selectCandidate(index) }
    }

    // MARK: - Confirm button

    private func confirmButton(encounter: Encounter) -> some View {
        Button {
            Task { await vm.confirmPiece() }
        } label: {
            Text(vm.selectedCandidateIndex != nil ? "このピースを選ぶ" : "ピースを選んでください")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    vm.selectedCandidateIndex != nil ? Color(hex: "A27BC8") : Color.gray.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 20)
                )
        }
        .disabled(vm.selectedCandidateIndex == nil)
        .padding(.top, 14)
    }
}

private extension String {
    func repeated(_ n: Int) -> String { String(repeating: self, count: n) }
}
