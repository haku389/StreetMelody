import SwiftUI

struct MelodyView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        MLTabScreen {
            MLTabTitle(title: "メロディ", subtitle: "ピースを選んでパズルを完成させよう")
        } content: {
            VStack(spacing: 0) {
                MLTabSummary(symbol: "music.note", title: "ひとつの出会いから、次の好きへ。", caption: "気になる曲を選んで、パズルに新しいピースを。", metrics: [("受け取れる出会い", "\(vm.encounters.filter { vm.cooldownRemaining(for: $0.id) == 0 }.count)件"), ("今日のピース", "\(vm.todayCollected.count)枚")])
                    .padding(.bottom, 18)
                if vm.encounters.isEmpty {
                    emptyState
                } else if vm.allEncountersDone {
                    todaySummary
                } else {
                    encounterProgress
                    if let enc = vm.activeEncounter {
                        candidateCarousel(encounter: enc)
                        carouselNav(encounter: enc)
                        actionButtons(encounter: enc)
                    }
                    encounterList
                }
            }
        }
        .onAppear { vm.ensureActiveEncounter() }
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.locale = Locale(identifier: "ja_JP"); return f
    }()

    // MARK: - 本日のまとめ（全ての出会いを選び終えたら表示）

    private var todaySummary: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                Text("🎶 今日の出会いは選び終わりました")
                    .font(.system(size: 15, weight: .black)).foregroundStyle(MLPalette.ink)
                Text("また新しい人とすれちがうと、次の出会いが届きます")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(20).mlCard()

            if vm.todayCollected.isEmpty {
                Text("今日はまだピースを取得していません")
                    .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                    .frame(maxWidth: .infinity).padding(20).mlCard()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日取得したピース（\(vm.todayCollected.count)）")
                        .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                    ForEach(vm.todayCollected) { item in
                        summaryRow(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(16).mlCard()
            }
        }
    }

    private func summaryRow(_ item: TodayCollect) -> some View {
        let track = vm.track(for: item.trackId)
        return HStack(spacing: 12) {
            if let t = track {
                ArtBlockView(track: t, cornerRadius: 10).mlThumbFrame(width: 80)
            } else {
                RoundedRectangle(cornerRadius: 10).fill(Color(hex: "EEE0F2")).mlThumbFrame(width: 80)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("🕒 \(Self.timeFmt.string(from: item.collectedAt)) · 👤 \(item.fromUserName) · 📍\(item.locationLabel)")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694")).lineLimit(1)
                Text(track?.displayArtist ?? "？？？")
                    .font(.system(size: 13, weight: .black)).foregroundStyle(MLPalette.ink).lineLimit(1)
                Text(track?.displayTitle ?? "？？？")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "A27BC8")).lineLimit(1)
                // 取得した“その時点”の所持ピース数（最終結果ではない）
                Text("この時 \(item.ownedCountAtCollection)/\(track?.pieceCount ?? 24) ピース")
                    .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "B29ABC"))
            }
            Spacer()
            if let t = track {
                Button { vm.navigate(to: t.isUnlocked ? .puzzle(trackId: t.id) : .mystery(trackId: t.id)) } label: {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .black)).foregroundStyle(Color(hex: "B29ABC"))
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Screen title


    // MARK: - Encounter progress bar

    private var encounterProgress: some View {
        let total = vm.encounters.count
        let idx   = vm.activeEncounterIndex
        let enc   = vm.encounters[safe: idx]

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(idx + 1) / \(total) 件目の出会い")
                    .font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<total, id: \.self) { i in
                        let done = vm.encounterCooldowns[vm.encounters[i].id] != nil
                        RoundedRectangle(cornerRadius: 3)
                            .fill(done ? Color(hex: "1A9E6E") : (i == idx ? Color(hex: "A27BC8") : Color(hex: "A27BC8").opacity(0.2)))
                            .frame(width: i == idx ? 18 : 8, height: 6)
                            .animation(.spring(duration: 0.3), value: idx)
                    }
                }
            }

            if let enc = enc {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: "A27BC8"))
                        .frame(width: 36, height: 36)
                        .overlay(Text("\(idx + 1)").font(.system(size: 13, weight: .black)).foregroundStyle(.white))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(enc.fromUserName) さん")
                            .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                        Label("\(enc.locationLabel) · \(enc.candidates.count)曲", systemImage: "mappin.and.ellipse")
                            .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                    }
                    Spacer()

                    if vm.friends.contains(where: { $0.userId == enc.fromUserId }) {
                        Label("フレンド", systemImage: "person.2.fill")
                            .font(.system(size: 10, weight: .black)).foregroundStyle(Color(hex: "A27BC8"))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color(hex: "A27BC8").opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                let cooldown = vm.cooldownRemaining(for: enc.id)
                if cooldown > 0 {
                    HStack(spacing: 8) {
                        Text("⏳").font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(enc.fromUserName) さんとのクールタイム中")
                                .font(.system(size: 11, weight: .black)).foregroundStyle(MLPalette.ink)
                            Text("あと \(vm.formatCooldown(cooldown)) で再度受信できます")
                                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                        }
                    }
                    .padding(10)
                    .background(Color(hex: "A27BC8").opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "A27BC8").opacity(0.25)))
                } else {
                    Text("パズルを選んで「このパズルにする」を押してください")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color(hex: "8D7694"))
                        .multilineTextAlignment(.center)
                }

                // すれ違った順にしか選べない（前の出会いには戻れない）
                Text("すれ違った順にパズルを選びます（前の人には戻れません）")
                    .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "B29ABC"))
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .mlCard(radius: 22, elevation: .low)
        .padding(.bottom, 14)
    }

    // MARK: - Carousel

    private func candidateCarousel(encounter: Encounter) -> some View {
        let candidates = encounter.candidates
        let idx = max(0, min(vm.carouselIndex, candidates.count - 1))

        return VStack(spacing: 0) {
            if candidates.indices.contains(idx) {
                let candidate = candidates[idx]
                mainCarouselCard(candidate: candidate, track: vm.track(for: candidate.trackId))
            }
        }
        .padding(.bottom, 4)
    }

    private func mainCarouselCard(candidate: Candidate, track: Track?) -> some View {
        // フル表示＝全ピース表示（フルピース集めるまではモザイク）／ピース確認＝所持ピースのみ表示
        let isFull = vm.carouselViewMode == "mosaic"
        let complete = track?.isComplete ?? false

        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                PuzzlePiecesView(ownedPieces: track?.ownedPieces ?? [],
                                 availablePieces: candidate.availablePieces,
                                 color: track?.color ?? "violet",
                                 seed: track?.id ?? "",
                                 thumbnailURL: track?.thumbnailURL,
                                 cornerRadius: 18,
                                 revealAll: isFull,
                                 blur: isFull && !complete)
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(track?.ownedPieces.count ?? 0) / \(track?.pieceCount ?? 24)")
                            .font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.black.opacity(0.45), in: Capsule())
                            .padding(8)
                    }
                    .shadow(color: Color(hex: "A27BC8").opacity(0.15), radius: 16, y: 8)

                Button {
                    vm.carouselViewMode = vm.carouselViewMode == "pieces" ? "mosaic" : "pieces"
                } label: {
                    Label(vm.carouselViewMode == "pieces" ? "フル表示" : "ピース確認", systemImage: vm.carouselViewMode == "pieces" ? "music.note" : "square.grid.3x3")
                        .font(.system(size: 9, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                .padding(8)
            }

            VStack(spacing: 4) {
                Text("\(candidate.sourceSlot) · \(String(repeating: "★", count: min(candidate.rarity, 5)))")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                Text(track?.displayArtist ?? "—")
                    .font(.system(size: 15, weight: .black)).foregroundStyle(MLPalette.ink)
                Text(track?.displayTitle ?? "—")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color(hex: "A27BC8"))
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Carousel nav

    private func carouselNav(encounter: Encounter) -> some View {
        let candidates = encounter.candidates
        let idx = max(0, min(vm.carouselIndex, candidates.count - 1))
        return HStack(spacing: 16) {
            Button {
                if vm.carouselIndex > 0 {
                    vm.carouselIndex -= 1
                    vm.selectedCandidateIndex = nil
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(vm.carouselIndex > 0 ? Color(hex: "A27BC8") : Color(hex: "B29ABC"))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "EEE0F2"), in: Circle())
                    .overlay(Circle().stroke(Color(hex: "EADCE7")))
            }
            .disabled(vm.carouselIndex <= 0)

            Text("\(idx + 1) / \(candidates.count)")
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))

            Button {
                if vm.carouselIndex < candidates.count - 1 {
                    vm.carouselIndex += 1
                    vm.selectedCandidateIndex = nil
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(vm.carouselIndex < candidates.count - 1 ? Color(hex: "A27BC8") : Color(hex: "B29ABC"))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: "EEE0F2"), in: Circle())
                    .overlay(Circle().stroke(Color(hex: "EADCE7")))
            }
            .disabled(vm.carouselIndex >= candidates.count - 1)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Action buttons

    private func actionButtons(encounter: Encounter) -> some View {
        let candidates = encounter.candidates
        let idx = max(0, min(vm.carouselIndex, candidates.count - 1))
        let onCooldown = vm.cooldownRemaining(for: encounter.id) > 0

        let candTrackId = candidates[safe: idx]?.trackId
        let previewLeft = candTrackId.map { vm.previewPlaysLeft(trackId: $0) } ?? 0
        let canPreview = candTrackId.map { vm.canPreview(trackId: $0) } ?? false

        return VStack(spacing: 10) {
            if let tid = candTrackId, vm.track(for: tid)?.hasYouTubeVideo == true {
                Button { vm.startPreview(trackId: tid) } label: {
                    Text(previewLeft > 0 ? "▶ 少し聴く（あと\(previewLeft)回）" : "本日の試聴回数を使い切りました")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(canPreview ? .white : Color(hex: "B29ABC"))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(
                            canPreview
                                ? LinearGradient(colors: [Color(hex: "B7D3E5"), Color(hex: "8CB4D0")], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [Color(hex: "EEE0F2"), Color(hex: "EEE0F2")], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .mlGlow(canPreview ? Color(hex: "3B8FE8") : .clear)
                }
                .buttonStyle(MLPressButtonStyle())
                .disabled(!canPreview)
            }

            Button {
                if !onCooldown {
                    vm.selectedCandidateIndex = idx
                    vm.navigate(to: .pieceSelect(encounterId: encounter.id, candidateIndex: idx))
                }
            } label: {
                Text(onCooldown ? "クールタイム中" : "このパズルにする")
                    .font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(
                        onCooldown
                            ? LinearGradient(colors: [Color(hex: "B29ABC"), Color(hex: "B29ABC")], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color(hex: "C3A2E4"), Color(hex: "A27BC8")], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .mlGlow(onCooldown ? .clear : Color(hex: "A27BC8"))
            }
            .disabled(onCooldown)
            .buttonStyle(MLPressButtonStyle())
        }
        .padding(.bottom, 24)
    }

    // MARK: - Encounter list

    private var encounterList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日の出会い")
                    .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
                Text("\(vm.encounters.count)件")
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                Spacer()
            }
            .padding(.bottom, 4)

            ForEach(Array(vm.encounters.enumerated()), id: \.element.id) { i, enc in
                let isActive = i == vm.activeEncounterIndex
                let onCooldown = vm.cooldownRemaining(for: enc.id) > 0
                // すれ違った順にしか選べない＝現在の出会い以外はロック（完了は✓表示）
                let isLocked = !isActive && !onCooldown
                let isFriend = vm.friends.contains { $0.userId == enc.fromUserId }

                Button {
                    // 順番固定のため切り替え操作はしない
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(onCooldown ? Color(hex: "1A9E6E").opacity(0.15)
                                  : isActive ? Color(hex: "A27BC8")
                                  : Color(hex: "A27BC8").opacity(0.12))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Group {
                                    if onCooldown {
                                        Text("✓").font(.system(size: 14, weight: .black))
                                            .foregroundStyle(Color(hex: "1A9E6E"))
                                    } else if isLocked {
                                        Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color(hex: "B29ABC"))
                                    } else {
                                        Text("\(i + 1)").font(.system(size: 14, weight: .black))
                                            .foregroundStyle(isActive ? .white : Color(hex: "A27BC8"))
                                    }
                                }
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(enc.fromUserName)
                                    .font(.system(size: 12, weight: .black)).foregroundStyle(MLPalette.ink)
                                    .lineLimit(1)
                                if isFriend {
                                    // フレンドの印（絵文字は端末によって「?」に化けるので記号にする）
                                    Image(systemName: "music.note").font(.system(size: 10, weight: .black))
                                        .foregroundStyle(MLPalette.primary)
                                        .accessibilityLabel("フレンド")
                                }
                            }
                            Label("\(enc.locationLabel) · \(enc.candidates.count)曲", systemImage: "mappin.and.ellipse")
                                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
                        }

                        Spacer()

                        if onCooldown {
                            let remaining = vm.cooldownRemaining(for: enc.id)
                            Text("済 · あと\(vm.formatCooldown(remaining))")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(Color(hex: "1A9E6E"))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(hex: "1A9E6E").opacity(0.1), in: Capsule())
                        } else if isActive {
                            Text("→ 今ここ")
                                .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "A27BC8"))
                        } else if isLocked {
                            Text("順番待ち")
                                .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "B29ABC"))
                        } else {
                            Text("受信可")
                                .font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(hex: "1A9E6E"))
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(isActive ? Color(hex: "A27BC8").opacity(0.06) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isActive ? Color(hex: "A27BC8") : Color(hex: "EADCE7"),
                                lineWidth: isActive ? 2 : 1))
                    .opacity(isLocked ? 0.45 : 1)
                }
                .buttonStyle(MLPressButtonStyle())
                .disabled(isLocked)
            }
        }
        .padding(16).mlCard()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note").font(.system(size: 44, weight: .black)).foregroundStyle(MLPalette.primary)
            Text("まだ出会いがありません")
                .font(.system(size: 14, weight: .black)).foregroundStyle(MLPalette.ink)
            Text("外出してすれちがいを待ちましょう")
                .font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "8D7694"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
