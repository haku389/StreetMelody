import Foundation
import UIKit

// LifeEvents — すれちがいを「人生の記録」へ送る（共通ハブ life-os-api）
//
// 端末 → 中継（workers/、streetmelody-relay）→ ハブ。**署名の鍵は端末に置かない**
// （life-os-api/docs/contract.md §3）。端末が言うのは「誰と・いつ」だけで、
// 日付（JST）・相手のハッシュ・「同じ人と同じ日は1件」は中継の先の DB が決める。
//
// ── 届くまで端末に残す
//
// BLE の重複防止（同じ相手6時間）はメモリ上にしかなく、圏外ですれちがうことも多い。
// 受け取ったらまず箱に入れ、中継が「入った」と答えたものだけ消す。
// 同じものを何度送っても、DB の主キーとハブの冪等キーが1件にまとめる。
//
// ── 呼ぶ所
//
//   すれちがいを受け取ったとき   LifeEvents.shared.encountered(otherUserID:at:)
//   ログインして BLE が動き始めたとき・前面に来たとき   flush()
//                               （溜まったぶんと、DB に溜まっていてまだハブへ
//                                流れていないぶんを流す。空でも送ってよい）
//   どちらも BLEManager と、ここの通知の購読で済ませてある
@MainActor
final class LifeEvents {
    static let shared = LifeEvents()

    /// 中継。**ここから先が署名する**
    static let relayURL = URL(string: "https://streetmelody-relay.haku-ohitsuji389.workers.dev/v1/encounters")!

    struct Pending: Codable, Equatable, Sendable {
        /// 端末の控えの id。中継の返りを突き合わせるためだけに使う
        let id: String
        /// **誰のすれちがいか**（小文字の user_id）。送るのは、いまログインしている
        /// 人が持ち主のものだけ。ほかの人のものは消さずに残し、その人が入ったときに送る
        let ownerUserID: String
        let otherUserID: String
        /// 受け取った瞬間（届いた時刻ではない。日付をずらさないため）
        let at: Date
    }

    /// v1 は持ち主を持たなかった（まだ誰にも出していないので、移し替えずに捨てる）
    private let key = "streetmelody.lifeEvents.pending.v2"
    private let oldKeys = ["streetmelody.lifeEvents.pending.v1"]
    private let defaults: UserDefaults
    private var flushing = false

    /// 中継の上限と同じ（1回200件まで）
    private let batch = 200
    /// DB は30日より前を断るので、それより古い控えは送らずに捨てる
    private let keepFor: TimeInterval = 30 * 86_400

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        for k in oldKeys { defaults.removeObject(forKey: k) }
        // 前面に来るたびに流す。ContentView / AppViewModel を触らずに済むよう、ここで聞く
        // （BLEManager.start が最初に shared に触るので、ログイン後から効く）
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in await LifeEvents.shared.flush() }
        }
    }

    /// 溜まっている数（画面に出すなら）
    var pendingCount: Int { load().count }

    /// すれちがいを受け取った。**同じ相手でも何度呼んでもよい**（1件にまとまる）。
    /// ownerUserID は、すれちがいを受け取った時点でログインしていた自分
    func encountered(otherUserID: String, ownerUserID: String, at: Date = Date()) {
        var items = load()
        items.append(Pending(id: UUID().uuidString, ownerUserID: ownerUserID.lowercased(),
                             otherUserID: otherUserID.lowercased(), at: at))
        save(items)
        Task { await flush() }
    }

    /// 溜まったぶんを中継へ送る。**失敗しても投げない**（次に前面へ来たときにまた送る）
    func flush() async {
        guard !flushing else { return }
        flushing = true
        defer { flushing = false }

        // 古すぎる控えは、送っても DB が断るだけなので捨てる（持ち主に関わらず）
        let now = Date()
        save(load().filter { now.timeIntervalSince($0.at) < keepFor })

        // **いまログインしている人のぶんだけ**送る。未ログインなら何もしない
        guard let me = await SupabaseClient.shared.userId?.lowercased() else { return }
        var mine = load().filter { $0.ownerUserID == me }

        // 空でも1回は送る。DB に溜まってハブへ流れていないぶんを、中継が流す
        repeat {
            let chunk = Array(mine.prefix(batch))
            guard let done = await send(chunk, as: me) else { return }   // 圏外・人が替わった → 残す
            save(load().filter { !done.contains($0.id) })
            mine = load().filter { $0.ownerUserID == me }
            // 1件も片付かなかったら止める。同じ束を送り続けないため
            // （返りの数が合わないとき、中継はどれも accepted にしない）
            if chunk.count < batch || (done.isEmpty && !chunk.isEmpty) { return }
        } while !mine.isEmpty
    }

    // MARK: -

    private struct Body: Encodable {
        let encounters: [Item]
        struct Item: Encodable { let id: String; let other_user_id: String; let occurred_at: String }
    }

    private struct Reply: Decodable {
        let accepted: [String]
        let rejected: [Rejected]
        struct Rejected: Decodable { let id: String; let reason: String }
    }

    /// 送って、控えから消してよい id（入った・送り直しても通らない）を返す。
    /// nil は「答えが聞けなかった／まだ送れない」。控えはそのまま残す
    private func send(_ chunk: [Pending], as me: String) async -> Set<String>? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let body = Body(encounters: chunk.map {
            .init(id: $0.id, other_user_id: $0.otherUserID, occurred_at: f.string(from: $0.at))
        })
        guard let data = try? JSONEncoder().encode(body),
              // 送る直前にも持ち主を確かめる（確かめてから送るまでに人が替わらないよう、actor の中で）
              let (out, status) = try? await SupabaseClient.shared.relayPOST(Self.relayURL, body: data, asUser: me),
              (200..<300).contains(status),
              let reply = try? JSONDecoder().decode(Reply.self, from: out)
        else { return nil }
        // 断られたものは送り直しても通らない（自分自身・知らない相手・30日より前など）
        return Set(reply.accepted).union(reply.rejected.map(\.id))
    }

    private func load() -> [Pending] {
        guard let d = defaults.data(forKey: key),
              let items = try? JSONDecoder().decode([Pending].self, from: d) else { return [] }
        return items
    }

    private func save(_ items: [Pending]) {
        if items.isEmpty { defaults.removeObject(forKey: key); return }
        if let d = try? JSONEncoder().encode(items) { defaults.set(d, forKey: key) }
    }
}
