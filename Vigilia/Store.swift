import SwiftUI
import UserNotifications
import AVFoundation

@MainActor
final class Store: ObservableObject {
    @Published var items: [Item] = []
    @Published var sounds: [String] = []
    @Published var playing: String? = nil

    private let key = "vigilia.items"
    private let nagCount = 2          // toques extras de alarme, 1 min depois um do outro
    private var player: AVAudioPlayer?

    private var soundsDir: URL {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let dir = lib.appendingPathComponent("Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode([Item].self, from: d) {
            items = v
        } else {
            items = [
                Item(kind: .alarm, hour: 5, minute: 30, label: "Toque de alvorada", weekdays: [2, 3, 4, 5, 6]),
                Item(kind: .reminder, hour: 6, minute: 15, label: "Oração da manhã")
            ]
        }
        refreshSounds()
    }

    func start() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        refresh()
    }

    /// Desliga o que já tocou (itens de uma vez só) e reagenda tudo.
    func refresh() {
        for k in items.indices where items[k].enabled && items[k].isOneShot
            && (items[k].at ?? .distantPast) < Date() { items[k].enabled = false }
        commit()
    }

    private func commit() {
        if let d = try? JSONEncoder().encode(items) { UserDefaults.standard.set(d, forKey: key) }
        reschedule()
    }

    func add(_ item: Item) { var i = item; i.arm(); items.append(i); commit() }
    func remove(_ ids: [UUID]) { items.removeAll { ids.contains($0.id) }; commit() }
    func setEnabled(_ id: UUID, _ on: Bool) {
        guard let k = items.firstIndex(where: { $0.id == id }) else { return }
        items[k].enabled = on
        if on { items[k].arm() }
        commit()
    }

    // MARK: Notificações

    private func reschedule() {
        let c = UNUserNotificationCenter.current()
        c.removeAllPendingNotificationRequests()
        for i in items where i.enabled {
            if i.isOneShot { guard let at = i.at, at > Date() else { continue } }
            requests(for: i).forEach { c.add($0) }
        }
    }

    private func requests(for i: Item) -> [UNNotificationRequest] {
        let cal = Calendar.current
        var out: [UNNotificationRequest] = []
        for n in 0...(i.kind == .alarm ? nagCount : 0) {
            let total = i.hour * 60 + i.minute + n
            let shift = total / 1440
            let h = (total % 1440) / 60, m = total % 60
            var trig: [(DateComponents, Bool, String)] = []
            if i.isOneShot, let at = i.at {
                let d = at.addingTimeInterval(Double(n) * 60)
                trig.append((cal.dateComponents([.year, .month, .day, .hour, .minute], from: d), false, "once"))
            } else if i.kind == .alarm {
                for wd in i.weekdays {
                    trig.append((DateComponents(hour: h, minute: m, weekday: (wd - 1 + shift) % 7 + 1), true, "d\(wd)"))
                }
            } else {
                trig.append((DateComponents(hour: h, minute: m), true, "daily"))
            }
            for (dc, rep, tag) in trig {
                let v = Verses.random
                let content = UNMutableNotificationContent()
                content.title = i.label.isEmpty ? (i.kind == .alarm ? "Alarme" : "Lembrete") : i.label
                content.body = "\(v.text) — \(v.ref)"
                content.sound = i.sound.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
                content.interruptionLevel = .timeSensitive
                out.append(UNNotificationRequest(
                    identifier: "\(i.id.uuidString)-\(tag)-\(n)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: rep)))
            }
        }
        return out
    }

    // MARK: Toques personalizados

    func refreshSounds() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: soundsDir.path)) ?? []
        sounds = files.filter { $0.hasSuffix(".caf") }.sorted()
    }

    /// Converte a música escolhida para .caf (até 29 s, limite do iOS para toques de notificação).
    func importSound(from url: URL) throws {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        let src = try AVAudioFile(forReading: url)
        let fmt = src.processingFormat
        let frames = min(src.length, AVAudioFramePosition(fmt.sampleRate * 29))
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(frames)) else { return }
        try src.read(into: buf, frameCount: AVAudioFrameCount(frames))
        var base = url.deletingPathExtension().lastPathComponent
            .map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
        if base.isEmpty { base = "toque" }
        let dest = soundsDir.appendingPathComponent(base + ".caf")
        try? FileManager.default.removeItem(at: dest)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: fmt.sampleRate,
            AVNumberOfChannelsKey: fmt.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let out = try AVAudioFile(forWriting: dest, settings: settings)
        try out.write(from: buf)
        refreshSounds()
    }

    func deleteSound(_ file: String) {
        stopPreview()
        try? FileManager.default.removeItem(at: soundsDir.appendingPathComponent(file))
        for k in items.indices where items[k].sound == file { items[k].sound = nil }
        refreshSounds(); commit()
    }

    func togglePreview(_ file: String) {
        if playing == file { stopPreview(); return }
        stopPreview()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: soundsDir.appendingPathComponent(file))
        player?.play()
        playing = file
    }

    func stopPreview() { player?.stop(); player = nil; playing = nil }
}
