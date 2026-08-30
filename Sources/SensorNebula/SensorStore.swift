import Foundation
import Network
import SwiftUI

struct SensorPacket: Codable {
    var bridgeVersion: Int?
    var timestamp: Double = 0
    var ax: Double = 0
    var ay: Double = 0
    var az: Double = -1
    var gx: Double = 0
    var gy: Double = 0
    var gz: Double = 0
    var roll: Double = 0
    var pitch: Double = 0
    var yaw: Double = 0
    var lidAngle: Double = 0
    var lux: Double = 0
    var lightChannels: [Double] = [0, 0, 0, 0]
    var bpm: Double = 0
    var confidence: Double = 0
    var vibration: Double = 0
    var fanRPM: [Double]?
    var fanAvailable: Bool?
}

struct HistorySample: Identifiable {
    let id = UUID()
    let time: Date
    let vibration: Double
    let bpm: Double
    let lux: Double
}

struct DeviceMetric: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let symbol: String
    let color: Color
}

@MainActor
final class SensorStore: ObservableObject {
    @Published var packet = SensorPacket()
    @Published var connected = false
    @Published var history: [HistorySample] = []
    @Published var events: [String] = []
    @Published var isRecording = false
    @Published var recorded: [SensorPacket] = []
    @Published var batteryPercent = "--"
    @Published var powerSource = "检测中"
    @Published var thermalState = "正常"
    @Published var uptime = "--"
    @Published var lastPacketAt: Date?

    private var listener: NWListener?
    private var healthTimer: Timer?
    private var systemTimer: Timer?
    private var bridgeLauncher: Process?
    private var previousVibrationLevel = 0
    private var activeBridgeVersion = 0
    private var orientationReady = false
    private var smoothRoll = 0.0
    private var smoothPitch = 0.0
    private var smoothYaw = 0.0
    private var previousRawYaw = 0.0
    private var smoothLidAngle = 0.0

    init() {
        startListener()
        startTimers()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !self.connected || self.packet.bridgeVersion != 4 else { return }
            self.startPrivilegedSensorBridge()
        }
    }

    private func startPrivilegedSensorBridge() {
        guard let sourceRoot = ProcessInfo.processInfo.environment["SENSOR_NEBULA_BRIDGE_ROOT"],
              !sourceRoot.isEmpty else {
            events.insert("未配置传感器桥接目录（SENSOR_NEBULA_BRIDGE_ROOT）", at: 0)
            return
        }
        let runtime = "/tmp/SensorNebulaRuntime-v4-\(getuid())"
        let fileManager = FileManager.default
        let runtimeURL = URL(fileURLWithPath: runtime)
        do {
            if fileManager.fileExists(atPath: runtime) { try fileManager.removeItem(at: runtimeURL) }
            try fileManager.createDirectory(at: runtimeURL, withIntermediateDirectories: true)
            for item in ["macimu", "motion_live.py", "sensor_nebula_bridge.py"] {
                try fileManager.copyItem(
                    at: URL(fileURLWithPath: sourceRoot).appendingPathComponent(item),
                    to: runtimeURL.appendingPathComponent(item)
                )
            }
        } catch {
            events.insert("无法准备传感器运行组件：\(error.localizedDescription)", at: 0)
            return
        }
        let python = "/opt/homebrew/bin/python3"
        let bridge = "\(runtime)/sensor_nebula_bridge.py"
        guard fileManager.fileExists(atPath: python), fileManager.fileExists(atPath: bridge) else {
            events.insert("本地传感器桥接文件不完整", at: 0)
            return
        }
        let pidFile = "/tmp/sensor-nebula-bridge.pid"
        let shellCommand = "for p in $(/bin/ps -axo pid=,command= | /usr/bin/awk '$0 ~ /Python .*SensorNebulaRuntime.*sensor_nebula_bridge.py/ {print $1}'); do /bin/kill $p 2>/dev/null || true; done; cd '\(runtime)' && '\(python)' '\(bridge)' </dev/null >/tmp/sensor-nebula-bridge.log 2>&1 & echo $! > '\(pidFile)'"
        let escaped = shellCommand.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            bridgeLauncher = task
        } catch {
            events.insert("无法启动传感器授权：\(error.localizedDescription)", at: 0)
        }
    }

    private func startListener() {
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, on: 45873)
            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .global(qos: .userInteractive))
                self?.receive(on: connection)
            }
            listener.start(queue: .global(qos: .userInteractive))
            self.listener = listener
        } catch {
            events.insert("监听器启动失败：\(error.localizedDescription)", at: 0)
        }
    }

    private nonisolated func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data, let decoded = try? JSONDecoder().decode(SensorPacket.self, from: data) {
                Task { @MainActor in self?.accept(decoded) }
            }
            if error == nil { self?.receive(on: connection) }
        }
    }

    private func accept(_ next: SensorPacket) {
        let incomingVersion = next.bridgeVersion ?? 0
        if incomingVersion < activeBridgeVersion { return }
        if incomingVersion > activeBridgeVersion {
            activeBridgeVersion = incomingVersion
            orientationReady = false
        }
        var filtered = next
        if !orientationReady {
            smoothRoll = next.roll
            smoothPitch = next.pitch
            // Yaw has no magnetic north reference on this Mac. Start from zero
            // and integrate only while the gyroscope confirms real movement.
            smoothYaw = 0
            previousRawYaw = next.yaw
            smoothLidAngle = next.lidAngle
            orientationReady = true
        } else {
            let alpha = 0.10
            smoothRoll += alpha * (next.roll - smoothRoll)
            smoothPitch += alpha * (next.pitch - smoothPitch)
            var yawDelta = next.yaw - previousRawYaw
            while yawDelta > 180 { yawDelta -= 360 }
            while yawDelta < -180 { yawDelta += 360 }
            previousRawYaw = next.yaw

            // A stationary SPU gyroscope commonly reports a small constant
            // offset. Discard that offset so it cannot accumulate into visible
            // horizontal rotation. Deliberate rotation is well above this band.
            let gyroSpeed = sqrt(next.gx * next.gx + next.gy * next.gy + next.gz * next.gz)
            // The bridge publishes about 20 frames/second. Static yaw drift is
            // normally only a few thousandths of a degree per frame, while a
            // real hand rotation is materially larger. Requiring both signals
            // prevents noise on an unrelated gyro axis from unlocking yaw.
            let isRealHorizontalTurn = abs(yawDelta) >= 0.025 && gyroSpeed >= 0.35
            if isRealHorizontalTurn {
                smoothYaw += yawDelta
            }
            while smoothYaw > 180 { smoothYaw -= 360 }
            while smoothYaw < -180 { smoothYaw += 360 }

            // The hinge sensor jitters slightly while the lid is stationary.
            // Ignore its sub-degree noise, but follow a deliberate lid movement
            // quickly enough for the 3D model to feel connected to the hardware.
            let lidDelta = next.lidAngle - smoothLidAngle
            if abs(lidDelta) >= 0.65 {
                let lidAlpha = abs(lidDelta) >= 5 ? 0.28 : 0.12
                smoothLidAngle += lidAlpha * lidDelta
            }
        }
        filtered.roll = smoothRoll
        filtered.pitch = smoothPitch
        filtered.yaw = smoothYaw
        filtered.lidAngle = smoothLidAngle
        packet = filtered
        connected = true
        lastPacketAt = .now
        history.append(.init(time: .now, vibration: next.vibration, bpm: next.bpm, lux: next.lux))
        if history.count > 240 { history.removeFirst(history.count - 240) }
        if isRecording { recorded.append(next) }

        let level = next.vibration > 0.004 ? 2 : (next.vibration > 0.0012 ? 1 : 0)
        if level > previousVibrationLevel {
            let label = level == 2 ? "检测到明显振动" : "检测到轻微振动"
            events.insert("\(Date.now.formatted(date: .omitted, time: .standard))  \(label)  \(String(format: "%.5f g", next.vibration))", at: 0)
            if events.count > 6 { events.removeLast() }
        }
        previousVibrationLevel = level
    }

    private func startTimers() {
        healthTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let lastPacketAt = self.lastPacketAt, Date().timeIntervalSince(lastPacketAt) > 2 {
                    self.connected = false
                }
            }
        }
        refreshSystemMetrics()
        systemTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshSystemMetrics() }
        }
    }

    private func refreshSystemMetrics() {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if let range = output.range(of: #"\d+%"#, options: .regularExpression) {
            batteryPercent = String(output[range])
        }
        powerSource = output.localizedCaseInsensitiveContains("AC Power") ? "电源适配器" : "电池供电"
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = "正常"
        case .fair: thermalState = "轻微升温"
        case .serious: thermalState = "较热"
        case .critical: thermalState = "过热"
        @unknown default: thermalState = "未知"
        }
        let seconds = ProcessInfo.processInfo.systemUptime
        uptime = "\(Int(seconds / 3600)) 小时"
    }

    func toggleRecording() {
        isRecording.toggle()
        if isRecording { recorded.removeAll() }
    }

    func exportCSV() -> URL? {
        guard !recorded.isEmpty else { return nil }
        var csv = "timestamp,accel_x,accel_y,accel_z,gyro_x,gyro_y,gyro_z,roll,pitch,yaw,lid_angle,lux,bpm,confidence,vibration\n"
        for p in recorded {
            let values: [Double] = [p.timestamp, p.ax, p.ay, p.az, p.gx, p.gy, p.gz,
                                    p.roll, p.pitch, p.yaw, p.lidAngle, p.lux,
                                    p.bpm, p.confidence, p.vibration]
            csv += values.map { String($0) }.joined(separator: ",") + "\n"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/SensorNebula-\(formatter.string(from: .now)).csv")
        do { try csv.write(to: url, atomically: true, encoding: .utf8); return url } catch { return nil }
    }
}
