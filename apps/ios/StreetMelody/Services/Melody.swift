import Foundation
import AVFoundation

// MARK: - Melody モデル
//
// 各ユーザー固有の約4秒のテーマ。メジャー・ペンタトニックに固定することで、
// 任意の2つを重ねても協和する（メロディミックスの前提・docs/melody-social-design.md §5）。
// 変更前提のため、メロディは自身の meta（key/tempo/bars）を保持して前方互換にする。

struct MelodyNote: Codable, Equatable, Sendable {
    var deg: Int      // ペンタ度数（0..4、5以上/負はオクターブ跨ぎ）
    var oct: Int      // 基準オクターブからの相対
    var start: Double // 開始（拍）
    var dur: Double   // 長さ（拍）
}

struct Melody: Codable, Equatable, Sendable {
    var notes: [MelodyNote]
    var keyMidi: Int = 60    // 主音 MIDI（C4=60）
    var tempo: Double = 110  // BPM
    var bars: Int = 2

    /// メジャー・ペンタトニックの半音オフセット
    static let pentatonic = [0, 2, 4, 7, 9]

    func midi(of n: MelodyNote) -> Int {
        let idx = ((n.deg % 5) + 5) % 5
        let octFromDeg = Int(floor(Double(n.deg) / 5.0))
        return keyMidi + (n.oct + octFromDeg) * 12 + Melody.pentatonic[idx]
    }
}

// MARK: - 生成（user_id シードで決定的＝その人固有・再現可能）

enum MelodyGenerator {
    static func generate(seed: String, tempo: Double = 110, bars: Int = 2) -> Melody {
        var rng = SplitMix64(seed: fnv1a(seed))
        let beats = bars * 4
        var notes: [MelodyNote] = []
        var t = 0.0
        var deg = 0
        while t < Double(beats) - 0.0001 {
            let remaining = Double(beats) - t
            let dur: Double = (remaining >= 1 && rng.nextBool()) ? 1.0 : 0.5
            let isLast = (t + dur) >= Double(beats) - 0.0001
            if isLast { deg = 0 }                       // 終止は主音に着地
            notes.append(MelodyNote(deg: deg, oct: 0, start: t, dur: dur))
            t += dur
            let steps = [-2, -1, -1, 1, 1, 2]           // 隣接中心・たまに3度
            deg = max(0, min(6, deg + steps[Int(rng.next() % UInt64(steps.count))]))
        }
        return Melody(notes: notes, keyMidi: 60, tempo: tempo, bars: bars)
    }

    private static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return h
    }
}

struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func nextBool() -> Bool { next() & 1 == 0 }
}

// MARK: - 音色（加算合成＋エンベロープ。アセット不要で数パターン）
//
// ユーザーごとに user_id から1つ割り当て＝「その人の音」。グローバル一意は
// 不可（種類が少ない）なので、ミックス時に2人が被らないよう片方をずらす（§ playMix）。

struct Timbre: Equatable, Sendable {
    let name: String
    let harmonics: [Double]   // 倍音の振幅（1倍,2倍,3倍,...）
    let attack: Double
    let release: Double
    let percussive: Bool      // true: 鳴ってから減衰（ピアノ等） / false: 持続（オルガン等）
    let decayRate: Double     // percussive の減衰速度

    static let all: [Timbre] = [
        Timbre(name: "ピアノ",   harmonics: [1.0, 0.5, 0.28, 0.14, 0.07], attack: 0.004, release: 0.08, percussive: true,  decayRate: 3.0),
        Timbre(name: "ベル",     harmonics: [1.0, 0.0, 0.0, 0.55, 0.0, 0.3], attack: 0.003, release: 0.12, percussive: true,  decayRate: 1.6),
        Timbre(name: "マリンバ", harmonics: [1.0, 0.15, 0.0, 0.5],          attack: 0.003, release: 0.05, percussive: true,  decayRate: 6.0),
        Timbre(name: "オルガン", harmonics: [1.0, 0.6, 0.4, 0.3, 0.2],      attack: 0.02,  release: 0.06, percussive: false, decayRate: 0),
        Timbre(name: "プラック", harmonics: [1.0, 0.7, 0.5, 0.3, 0.15],     attack: 0.002, release: 0.05, percussive: true,  decayRate: 4.5),
    ]

    /// user_id 等のシードから決定的に1音色を割り当て。
    static func forSeed(_ seed: String) -> Timbre {
        var h: UInt64 = 0xcbf29ce484222325
        for b in (seed + "#timbre").utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return all[Int(h % UInt64(all.count))]
    }
    var index: Int { Timbre.all.firstIndex(of: self) ?? 0 }

    func envelope(_ t: Double, _ dur: Double) -> Double {
        var a = t < attack ? t / attack : 1.0
        if percussive { a *= exp(-decayRate * t) }
        if t > dur - release { a *= max(0, (dur - t) / release) }
        return a
    }
}

// MARK: - 再生（AVAudioEngine + 自前加算合成。アセット不要）

final class MelodyPlayer {
    static let shared = MelodyPlayer()

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private let sr: Double = 44100

    // 再生スケジュール（render スレッドが読む。開始前に確定し、再生中は変更しない）
    private struct Voice { let freq: Double; let start: Double; let end: Double; let gain: Double; let timbre: Timbre }
    private var voices: [Voice] = []
    private var total: Double = 0
    private var frame: Double = 0

    /// 単体メロディを試聴（音色は user_id 由来で割り当てた Timbre）。
    func play(_ melody: Melody, timbre: Timbre, octaveShift: Int = 0, gain: Double = 0.22) {
        start(voices: makeVoices(melody, timbre: timbre, octaveShift: octaveShift, gain: gain),
              total: totalSeconds(melody))
    }

    /// 2人のメロディを混ぜて再生。音色が同じなら片方をずらして必ず聞き分け＆住み分け。
    func playMix(_ a: Melody, timbreA ta: Timbre, _ b: Melody, timbreB tb0: Timbre) {
        let tb = (tb0 == ta) ? Timbre.all[(ta.index + 1) % Timbre.all.count] : tb0
        let va = makeVoices(a, timbre: ta, octaveShift: 0, gain: 0.20)
        let vb = makeVoices(b, timbre: tb, octaveShift: 1, gain: 0.16)   // 相手は+1oct
        start(voices: va + vb, total: max(totalSeconds(a), totalSeconds(b)))
    }

    func stop() {
        if let s = source { engine.detach(s); source = nil }
        if engine.isRunning { engine.stop() }
    }

    // MARK: helpers

    private func totalSeconds(_ m: Melody) -> Double { Double(m.bars * 4) * (60.0 / m.tempo) + 0.3 }

    private func makeVoices(_ m: Melody, timbre: Timbre, octaveShift: Int, gain: Double) -> [Voice] {
        let spb = 60.0 / m.tempo
        return m.notes.map { n in
            let midi = m.midi(of: n) + octaveShift * 12
            let f = 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
            let s = n.start * spb
            let e = (n.start + n.dur) * spb - 0.02
            return Voice(freq: f, start: s, end: max(s + 0.08, e), gain: gain, timbre: timbre)
        }
    }

    private func start(voices: [Voice], total: Double) {
        stop()
        configureSession()
        self.voices = voices; self.total = total; self.frame = 0
        let sr = self.sr
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
        let src = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
            guard let self else { return noErr }
            let bufs = UnsafeMutableAudioBufferListPointer(abl)
            let count = Int(frameCount)
            for i in 0..<count {
                let t = (self.frame + Double(i)) / sr
                var s: Float = 0
                if t <= self.total {
                    for v in self.voices where t >= v.start && t <= v.end {
                        let local = t - v.start
                        let amp = v.timbre.envelope(local, v.end - v.start)
                        var sample = 0.0, norm = 0.0
                        for (k, h) in v.timbre.harmonics.enumerated() where h != 0 {
                            sample += h * sin(2.0 * Double.pi * v.freq * Double(k + 1) * local)
                            norm += h
                        }
                        if norm > 0 { sample /= norm }
                        s += Float(sample * amp * v.gain)
                    }
                }
                for buf in bufs {
                    buf.mData!.assumingMemoryBound(to: Float.self)[i] = s
                }
            }
            self.frame += Double(count)
            return noErr
        }
        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: fmt)
        source = src
        do { try engine.start() } catch { /* 試聴のみ・失敗は無視 */ }
    }

    private func configureSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default)
        try? s.setActive(true)
    }
}
