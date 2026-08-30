import Foundation

struct TouchFrame: Decodable {
    let frame: Int
    let timestamp: Double
    let touches: [TouchPoint]
}

struct TouchPoint: Decodable, Identifiable {
    let id: Int
    let state: Int
    let x: Double
    let y: Double
    let pressure: Double
    let size: Double
    let major: Double
    let minor: Double
    let density: Double
    let zPressure: Double
}

@MainActor
final class TouchpadMonitor: ObservableObject {
    static let shared = TouchpadMonitor()

    @Published var touches: [TouchPoint] = []
    @Published var status = "正在连接触控板…"
    @Published var available = false
    @Published var frameRate = 0

    private var process: Process?
    private var pending = Data()
    private var framesThisSecond = 0
    private var lastRateUpdate = Date()

    private init() { start() }

    func start() {
        guard process == nil else { return }
        guard let executableFolder = Bundle.main.executableURL?.deletingLastPathComponent() else {
            status = "无法定位触控板桥接程序"; return
        }
        let helper = executableFolder.appendingPathComponent("TouchBridge")
        guard FileManager.default.isExecutableFile(atPath: helper.path) else {
            status = "触控板桥接程序未安装"; return
        }
        let task = Process()
        let output = Pipe()
        let errors = Pipe()
        task.executableURL = helper
        task.standardOutput = output
        task.standardError = errors
        task.terminationHandler = { [weak self] task in
            Task { @MainActor in
                self?.available = false
                self?.status = "触控板连接已停止（\(task.terminationStatus)）"
                self?.process = nil
            }
        }
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in self?.consume(data) }
        }
        errors.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let message = String(data: data, encoding: .utf8), !message.isEmpty else { return }
            Task { @MainActor in
                if message.contains("touchbridge_ready") {
                    self?.available = true
                    self?.status = "触控板已连接，请放上手指"
                } else if !message.contains("Recognized") {
                    self?.status = message.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        do {
            try task.run()
            process = task
        } catch {
            status = "启动失败：\(error.localizedDescription)"
        }
    }

    private func consume(_ data: Data) {
        pending.append(data)
        while let newline = pending.firstIndex(of: 10) {
            let line = pending.prefix(upTo: newline)
            pending.removeSubrange(...newline)
            guard let frame = try? JSONDecoder().decode(TouchFrame.self, from: line) else { continue }
            touches = frame.touches.filter { $0.x.isFinite && $0.y.isFinite }
            available = true
            status = touches.isEmpty ? "触控板已连接，请放上手指" : "正在读取 \(touches.count) 个触点"
            framesThisSecond += 1
            if Date().timeIntervalSince(lastRateUpdate) >= 1 {
                frameRate = framesThisSecond
                framesThisSecond = 0
                lastRateUpdate = .now
            }
        }
    }
}
