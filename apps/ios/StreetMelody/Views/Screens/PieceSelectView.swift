import SwiftUI

struct PieceSelectView: View {
    let encounterId: String
    let candidateIndex: Int
    @EnvironmentObject var vm: AppViewModel

    private var encounter: Encounter? { vm.encounters.first { $0.id == encounterId } }
    private var candidate: Candidate? {
        guard let enc = encounter, enc.candidates.indices.contains(candidateIndex)
        else { return nil }
        return enc.candidates[candidateIndex]
    }
    private var track: Track? {
        guard let c = candidate else { return nil }
        return vm.track(for: c.trackId)
    }

    let cols = 6
    let rows = 4

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let t = track, let c = candidate {
                    headerCard(track: t)
                    pieceGrid(track: t, candidate: c)
                    legend
                    backButton
                } else {
                    Text("データが見つかりません")
                        .foregroundStyle(Color(hex: "7B6F8A"))
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 112)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "F5F0FF").ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color(hex: "F5F0FF"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .heavy)).foregroundStyle(Color(hex: "7248E0"))
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(track?.displayArtist ?? "—")
                        .font(.system(size: 14, weight: .black)).foregroundStyle(.primary)
                    Text(track?.displayTitle ?? "—")
                        .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                }
            }
        }
    }

    private func headerCard(track: Track) -> some View {
        VStack(spacing: 8) {
            Text("取得したいピースを1つ選んでください")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Color(hex: "7B6F8A"))
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)
        }
        .padding(.bottom, 12)
    }

    private let gap: CGFloat = 2

    private func pieceGrid(track: Track, candidate: Candidate) -> some View {
        let owned = track.ownedPieces
        let available = candidate.availablePieces.filter { !owned.contains($0) }
        let seed = track.id
        let url = track.thumbnailURL

        // 16:9 を 6×4 に分割。所持ピースは独自生成カードの該当領域を切り出して表示し、
        // 取得可能ピースはハイライト＋タップ、取得不可は lockedピースで隠す（設計書 §8.2）。
        return GeometryReader { geo in
            let w = geo.size.width
            let h = w * 9.0 / 16.0
            let cellW = (w - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let cellH = (h - gap * CGFloat(rows - 1)) / CGFloat(rows)
            ZStack(alignment: .topLeading) {
                ForEach(0..<(cols * rows), id: \.self) { i in
                    let n = i + 1, r = i / cols, c = i % cols
                    pieceCell(n: n, r: r, c: c, owned: owned, available: available,
                              seed: seed, url: url, color: track.color,
                              fullW: w, fullH: h, cellW: cellW, cellH: cellH)
                        .frame(width: cellW, height: cellH)
                        .position(x: cellW / 2 + CGFloat(c) * (cellW + gap),
                                  y: cellH / 2 + CGFloat(r) * (cellH + gap))
                }
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func pieceCell(n: Int, r: Int, c: Int, owned: [Int], available: [Int],
                           seed: String, url: URL?, color: String,
                           fullW: CGFloat, fullH: CGFloat, cellW: CGFloat, cellH: CGFloat) -> some View {
        if owned.contains(n) {
            // サムネイルの該当ピース領域を切り出して表示
            Color.clear
                .overlay(alignment: .topLeading) {
                    MelodyCardArtwork(color: color, seed: seed, thumbnailURL: url)
                    .frame(width: fullW, height: fullH)
                    .offset(x: -CGFloat(c) * (cellW + gap), y: -CGFloat(r) * (cellH + gap))
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(alignment: .topLeading) {
                    Text("✓")
                        .font(.system(size: 7, weight: .black)).foregroundStyle(.white)
                        .padding(2)
                        .background(Color(hex: "1A9E6E"), in: Circle())
                        .padding(2)
                }
        } else if available.contains(n) {
            Button {
                vm.collectPiece(encounterId: encounterId, candidateIndex: candidateIndex, pieceNumber: n)
            } label: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "7248E0").opacity(0.45))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.9), lineWidth: 1.5))
                    .overlay(Text("\(n)").font(.system(size: 9, weight: .black)).foregroundStyle(.white))
            }
            .buttonStyle(.plain)
        } else {
            // 取得不可：lockedピース（淡い紫）
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: "E3DAF5"))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: "D3C7EE"), lineWidth: 0.5))
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: Color(hex: "7248E0").opacity(0.45), label: "取得可能")
            legendItem(color: Color(hex: "1A9E6E"),               label: "所持済み")
            legendItem(color: Color(hex: "E3DAF5"),               label: "取得不可")
        }
        .font(.system(size: 10, weight: .heavy))
        .foregroundStyle(Color(hex: "7B6F8A"))
        .padding(.bottom, 14)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }

    private var backButton: some View {
        Button { vm.goBack() } label: {
            Text("‹ パズルを選び直す")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color(hex: "7248E0"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "EDE8FF"), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "E0D8F7")))
        }
        .buttonStyle(.plain)
    }
}
