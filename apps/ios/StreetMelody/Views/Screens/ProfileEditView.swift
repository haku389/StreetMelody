import SwiftUI
import UIKit

// MARK: - ProfileEditView（アプリ独自UI）

struct ProfileEditView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var handle = ""
    @State private var displayName = ""
    @State private var bio = ""
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var didLoad = false   // お気に入り画面から戻った時に入力を消さないため一度だけロード
    @State private var gender = "na"
    @State private var favArtists: Set<String> = []
    @State private var favTracks: Set<String> = []
    @State private var visBirthday = "private"
    @State private var visGender = "private"

    @State private var handleState: HandleState = .idle
    @State private var checkTask: Task<Void, Never>? = nil
    @State private var saving = false
    @State private var errorText: String? = nil

    enum HandleState: Equatable { case idle, checking, available, taken, invalid }

    private let genders = [("male", "男性"), ("female", "女性"), ("other", "その他"), ("na", "回答しない")]
    private let scopes = [("public", "公開"), ("followers", "フォロワー"), ("friends", "フレンド"), ("best", "ベスト"), ("private", "非公開")]
    private let purple = Color(hex: "7248E0")
    private let lilac = Color(hex: "EDE8FF")
    private let field = Color(hex: "F5F0FF")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    handleCard
                    basicCard
                    favoritesCard
                    melodyCard
                    privacyCard
                    if let e = errorText {
                        Text(e).font(.system(size: 12, weight: .heavy)).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    saveButton
                }
                .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(field.ignoresSafeArea())
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // テスト用：常に閉じられる✕ボタン
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .onAppear(perform: loadFromVM)
        }
    }

    // MARK: Cards

    private var handleCard: some View {
        card("ユーザーID（必ず公開）") {
            HStack(spacing: 8) {
                Text("@").font(.system(size: 15, weight: .black)).foregroundStyle(Color(hex: "B8ACD6"))
                TextField("英数字と - _ ・1〜16文字", text: $handle)
                    .font(.system(size: 14, weight: .heavy))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: handle) { _, v in scheduleHandleCheck(v) }
                handleBadge
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(field, in: RoundedRectangle(cornerRadius: 12))
            Text(handleHint).font(.system(size: 10, weight: .heavy))
                .foregroundStyle(handleState == .taken || handleState == .invalid ? .red : Color(hex: "B8ACD6"))
                .padding(.top, 6)
        }
    }

    private var basicCard: some View {
        card("基本（名前・自己紹介は必ず公開）") {
            styledField("表示名", text: $displayName)
            styledField("自己紹介", text: $bio, multiline: true).padding(.top, 8)
        }
    }

    private var favoritesCard: some View {
        card("好きなアーティスト・曲（必ず公開）") {
            favoriteRow(label: "好きなアーティスト", selection: $favArtists,
                        appItems: vm.artistGroups.map { $0.name }, kind: .artist)
            Divider().background(Color(hex: "E0D8F7")).padding(.vertical, 10)
            favoriteRow(label: "好きな曲", selection: $favTracks,
                        appItems: vm.tracks.values.compactMap { $0.title }.sorted(), kind: .song)
        }
    }

    private var melodyCard: some View {
        card("メロディ（あなたのテーマ）") {
            Button { vm.playMyMelody() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                    Text("マイメロディを試聴（音色: \(vm.myTimbreName)）")
                }
                .font(.system(size: 13, weight: .black)).foregroundStyle(purple)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(lilac, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var privacyCard: some View {
        card("誕生日・性別（公開範囲を選べます）") {
            HStack {
                Text("誕生日（必須）").font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
                Spacer()
                DatePicker("", selection: $birthday, in: ...Date(), displayedComponents: .date)
                    .labelsHidden().tint(purple)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
            }
            scopeRow("誕生日の公開範囲", selection: $visBirthday).padding(.top, 8)
            Divider().background(Color(hex: "E0D8F7")).padding(.vertical, 10)
            Text("性別").font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            chips(genders, selection: $gender)
            scopeRow("性別の公開範囲", selection: $visGender).padding(.top, 8)
        }
    }

    private var saveButton: some View {
        Button { Task { await save() } } label: {
            Text(saving ? "保存中…" : "保存する")
                .font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(canSave ? purple : Color(hex: "C9BEF0"), in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(saving || !canSave)
    }

    // MARK: 小物

    private func card<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 12, weight: .black)).foregroundStyle(Color(hex: "3D2F60"))
                .padding(.bottom, 12)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).mlCard()
    }

    private func styledField(_ placeholder: String, text: Binding<String>, multiline: Bool = false) -> some View {
        Group {
            if multiline {
                TextField(placeholder, text: text, axis: .vertical).lineLimit(1...4)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .font(.system(size: 14, weight: .heavy))
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(field, in: RoundedRectangle(cornerRadius: 12))
    }

    private func chips(_ items: [(String, String)], selection: Binding<String>) -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.0) { item in
                let on = selection.wrappedValue == item.0
                Button { selection.wrappedValue = item.0 } label: {
                    Text(item.1).font(.system(size: 12, weight: .black))
                        .foregroundStyle(on ? .white : Color(hex: "7B6F8A"))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(on ? purple : lilac, in: Capsule())
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func scopeRow(_ label: String, selection: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A"))
            Spacer()
            Menu {
                ForEach(scopes, id: \.0) { s in Button(s.1) { selection.wrappedValue = s.0 } }
            } label: {
                HStack(spacing: 4) {
                    Text(scopes.first { $0.0 == selection.wrappedValue }?.1 ?? "非公開")
                    Image(systemName: "chevron.down").font(.system(size: 9))
                }
                .font(.system(size: 12, weight: .black)).foregroundStyle(purple)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(lilac, in: Capsule())
            }
        }
    }

    private func favoriteRow(label: String, selection: Binding<Set<String>>, appItems: [String], kind: FavoritePickerView.Kind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink {
                FavoritePickerView(title: label, kind: kind, appItems: appItems, selection: selection)
                    .environmentObject(vm)
            } label: {
                HStack {
                    Text(label).font(.system(size: 13, weight: .black)).foregroundStyle(.primary)
                    Spacer()
                    Text("\(selection.wrappedValue.count)件 ＋")
                        .font(.system(size: 12, weight: .black)).foregroundStyle(purple)
                }
            }
            if !selection.wrappedValue.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(selection.wrappedValue).sorted(), id: \.self) { name in
                            HStack(spacing: 4) {
                                Text(name).font(.system(size: 11, weight: .black)).foregroundStyle(purple)
                                Button { selection.wrappedValue.remove(name) } label: {
                                    Image(systemName: "xmark").font(.system(size: 8, weight: .black)).foregroundStyle(Color(hex: "B8ACD6"))
                                }
                            }
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .background(lilac, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var handleBadge: some View {
        Group {
            switch handleState {
            case .checking: ProgressView().scaleEffect(0.7)
            case .available: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .taken, .invalid: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .idle: EmptyView()
            }
        }
    }
    private var handleHint: String {
        switch handleState {
        case .taken: return "そのIDは使われています"
        case .invalid: return "半角英数字と - _ のみ・1〜16文字"
        default: return "フレンドがあなたを探すためのID。共通アカウントなので StyleCare などでも同じIDです（変更は一定期間に1回まで）"
        }
    }

    // MARK: ロジック

    private var canSave: Bool {
        let h = handle.trimmingCharacters(in: .whitespaces)
        return !h.isEmpty && handleState != .taken && handleState != .invalid && handleState != .checking
    }

    private func loadFromVM() {
        guard !didLoad else { return }   // 子画面から戻った時に上書きしない
        didLoad = true
        let p = vm.profile
        handle = p.handle ?? ""
        displayName = p.displayName ?? vm.user?.name ?? ""
        bio = p.bio ?? ""
        gender = p.gender ?? "na"
        favArtists = Set(p.favoriteArtistIds)
        favTracks = Set(p.favoriteTrackIds)
        if let b = p.birthday, let d = Self.dateFmt.date(from: b) { birthday = d }
        visBirthday = p.visibility["birthday"] ?? "private"
        visGender = p.visibility["gender"] ?? "private"
        handleState = .idle
    }

    private func scheduleHandleCheck(_ raw: String) {
        checkTask?.cancel()
        let h = raw.lowercased()
        guard isValidHandle(h) else { handleState = .invalid; return }
        if h == (vm.profile.handle?.lowercased() ?? "") { handleState = .idle; return }
        handleState = .checking
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            let ok = await vm.checkHandle(h)
            if Task.isCancelled { return }
            handleState = ok ? .available : .taken
        }
    }

    private func isValidHandle(_ h: String) -> Bool {
        // 共通アカウント（public.is_valid_handle）と同じ決まり：半角英数字と - _、1〜16文字
        h.range(of: "^[a-z0-9_-]{1,16}$", options: .regularExpression) != nil
    }

    private func save() async {
        errorText = nil
        guard isValidHandle(handle.lowercased()) else { handleState = .invalid; return }
        saving = true; defer { saving = false }
        var p = vm.profile
        p.handle = handle.lowercased()
        p.displayName = displayName.isEmpty ? nil : displayName
        p.bio = bio.isEmpty ? nil : bio
        p.gender = gender
        p.favoriteArtistIds = Array(favArtists)
        p.favoriteTrackIds = Array(favTracks)
        p.birthday = Self.dateFmt.string(from: birthday)   // 必須
        p.visibility["birthday"] = visBirthday
        p.visibility["gender"] = visGender
        if let err = await vm.saveProfile(p) { errorText = err; return }
        dismiss()
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
}

// MARK: - FavoritePickerView（Apple Music ライブラリ / アプリ / 手動 の3ソース）

struct FavoritePickerView: View {
    enum Kind { case artist, song }

    @EnvironmentObject var vm: AppViewModel
    let title: String
    let kind: Kind
    let appItems: [String]
    @Binding var selection: Set<String>

    @State private var source = 0        // 0: Apple Music 全カタログ / 1: アプリ / 2: 手動
    @State private var search = ""
    @State private var results: [ITunesSearch.Result] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var manualText = ""

    private let purple = Color(hex: "7248E0")
    private let lilac = Color(hex: "EDE8FF")

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $source) {
                Text("Apple Music").tag(0); Text("アプリ").tag(1); Text("手動").tag(2)
            }
            .pickerStyle(.segmented).padding(16)

            if source == 2 {
                manualEntry
            } else {
                searchField
                List {
                    if source == 0 {
                        if searching { HStack { Spacer(); ProgressView(); Spacer() } }
                        ForEach(results) { r in catalogRow(r) }
                        if !searching && results.isEmpty {
                            Text(search.isEmpty ? "曲名・アーティスト名で検索（Apple Music 全カタログ）"
                                                : "見つかりませんでした")
                                .foregroundStyle(.secondary).font(.system(size: 13, weight: .heavy))
                        }
                    } else {
                        ForEach(appFiltered, id: \.self) { name in
                            Button { toggle(name) } label: { selectableRow(name, subtitle: nil) }
                        }
                        if appFiltered.isEmpty { Text("候補がありません").foregroundStyle(.secondary) }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: search) { _, v in if source == 0 { scheduleSearch(v) } }
        .onChange(of: source) { _, _ in results = []; if source == 0 { scheduleSearch(search) } }
    }

    private func catalogRow(_ r: ITunesSearch.Result) -> some View {
        Button { toggle(r.name) } label: {
            HStack(spacing: 10) {
                AsyncImage(url: r.artworkUrl.flatMap { URL(string: $0) }) { img in
                    img.resizable().scaledToFill()
                } placeholder: { Color(hex: "EDE8FF") }
                .frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.name).font(.system(size: 13, weight: .black)).foregroundStyle(.primary).lineLimit(1)
                    if !r.subtitle.isEmpty {
                        Text(r.subtitle).font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: "7B6F8A")).lineLimit(1)
                    }
                }
                Spacer()
                if selection.contains(r.name) { Image(systemName: "checkmark").foregroundStyle(purple) }
            }
        }
    }

    private func selectableRow(_ name: String, subtitle: String?) -> some View {
        HStack {
            Text(name).foregroundStyle(.primary)
            Spacer()
            if selection.contains(name) { Image(systemName: "checkmark").foregroundStyle(purple) }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color(hex: "B8ACD6"))
            TextField(source == 0 ? "Apple Music を検索" : "絞り込み", text: $search)
                .font(.system(size: 14, weight: .heavy))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(hex: "F5F0FF"), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    private var manualEntry: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField(kind == .artist ? "アーティスト名を入力" : "曲名を入力", text: $manualText)
                    .font(.system(size: 14, weight: .heavy))
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(Color(hex: "F5F0FF"), in: RoundedRectangle(cornerRadius: 12))
                Button("追加") {
                    let t = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { selection.insert(t); manualText = "" }
                }
                .font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(purple, in: RoundedRectangle(cornerRadius: 12))
            }
            ScrollView {
                FlowChips(items: Array(selection).sorted()) { name in
                    HStack(spacing: 4) {
                        Text(name).font(.system(size: 11, weight: .black)).foregroundStyle(purple)
                        Button { selection.remove(name) } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .black)).foregroundStyle(Color(hex: "B8ACD6"))
                        }
                    }
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(lilac, in: Capsule())
                }
            }
            Spacer()
        }
        .padding(16)
    }

    private var appFiltered: [String] {
        guard !search.isEmpty else { return appItems }
        return appItems.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    private func toggle(_ name: String) {
        if selection.contains(name) { selection.remove(name) } else { selection.insert(name) }
    }

    private func scheduleSearch(_ term: String) {
        searchTask?.cancel()
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { results = []; searching = false; return }
        searching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            let res = await ITunesSearch.search(term: t, isArtist: kind == .artist)
            if Task.isCancelled { return }
            results = res; searching = false
        }
    }
}

// 簡易フローレイアウト（チップ折り返し）
struct FlowChips<Content: View>: View {
    let items: [String]
    @ViewBuilder let content: (String) -> Content
    var body: some View {
        var width = CGFloat.zero
        var rows: [[String]] = [[]]
        // 概算で折り返し（正確なレイアウトは Layout で行うが簡易版）
        for item in items {
            let est = CGFloat(item.count) * 10 + 40
            if width + est > UIScreen.main.bounds.width - 32 { rows.append([item]); width = est }
            else { rows[rows.count - 1].append(item); width += est }
        }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) { ForEach(row, id: \.self) { content($0) }; Spacer(minLength: 0) }
            }
        }
    }
}
