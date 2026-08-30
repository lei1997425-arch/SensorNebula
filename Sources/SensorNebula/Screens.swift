import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var store: SensorStore
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    MetricTile(icon: "waveform.path", title: "振动强度", value: String(format: "%.5f", store.packet.vibration), unit: "g", color: .cyan)
                    MetricTile(icon: "heart.fill", title: "实验心率", value: store.packet.bpm > 0 ? String(format: "%.0f", store.packet.bpm) : "--", unit: "BPM", color: .pink)
                    MetricTile(icon: "sun.max.fill", title: "环境光", value: String(format: "%.1f", store.packet.lux), unit: "lux", color: .yellow)
                    MetricTile(icon: "laptopcomputer", title: "屏幕角度", value: String(format: "%.0f°", store.packet.lidAngle), unit: "", color: .purple)
                }
                HStack(alignment: .top, spacing: 18) {
                    GlassCard("实时振动场", subtitle: "加速度计微振动 · 最近 12 秒") {
                        NeonChart(values: store.history.map(\.vibration), color: .cyan).frame(height: 205)
                        HStack { Label("X \(store.packet.ax, specifier: "%.4f")", systemImage: "xmark"); Spacer(); Text("Y \(store.packet.ay, specifier: "%.4f")"); Spacer(); Text("Z \(store.packet.az, specifier: "%.4f")") }.font(.caption.monospaced()).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity)
                    GlassCard("机身姿态", subtitle: "前后/左右倾斜由重力校正 · 水平转向为相对方向") {
                        HStack(spacing: 18) {
                            CircularGauge(value: abs(store.packet.roll), maxValue: 45, title: "前后倾斜", display: String(format: "%.1f°", -store.packet.roll), color: .cyan)
                            CircularGauge(value: abs(store.packet.pitch), maxValue: 45, title: "左右倾斜", display: String(format: "%.1f°", -store.packet.pitch), color: .purple)
                            CircularGauge(value: abs(store.packet.yaw), maxValue: 180, title: "水平转向（相对）", display: String(format: "%.1f°", store.packet.yaw), color: .pink)
                        }.frame(height: 170)
                    }.frame(width: 460)
                }
                HStack(alignment: .top, spacing: 18) {
                    GlassCard("传感器阵列", subtitle: "当前机型能力") {
                        SensorRow(name: "加速度计", detail: "3 轴 · 高频采样", live: store.connected)
                        SensorRow(name: "陀螺仪", detail: "3 轴 · 角速度", live: store.connected)
                        SensorRow(name: "环境光", detail: "照度 · 4 光谱通道", live: store.connected)
                        SensorRow(name: "屏幕角度", detail: "机盖开合角", live: store.connected)
                    }.frame(maxWidth: .infinity)
                    GlassCard("最近事件", subtitle: "振动与系统信号") {
                        if store.events.isEmpty { Text("正在等待事件…").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 118) }
                        ForEach(store.events.prefix(4), id: \.self) { event in Text(event).font(.caption.monospaced()).foregroundStyle(.green).lineLimit(1) }
                    }.frame(width: 460)
                }
            }
        }
    }
}

struct RealtimePoseView: View {
    @EnvironmentObject var store: SensorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                MetricTile(icon: "arrow.up.and.down.and.arrow.left.and.right", title: "前后倾斜", value: String(format: "%+.1f°", -store.packet.roll), unit: "", color: .cyan)
                MetricTile(icon: "arrow.left.and.right", title: "左右倾斜", value: String(format: "%+.1f°", -store.packet.pitch), unit: "", color: .purple)
                MetricTile(icon: "rotate.3d", title: "水平转向（相对）", value: String(format: "%+.1f°", store.packet.yaw), unit: "", color: .pink)
                MetricTile(icon: "laptopcomputer", title: "屏幕开合角度", value: String(format: "%.0f°", store.packet.lidAngle), unit: "", color: .orange)
            }
            GlassCard("14 英寸 MacBook Pro · 实时 3D 姿态", subtitle: "模型与传感器同步 · 可拖动旋转和滚轮缩放") {
                MacBookPoseCard(roll: -store.packet.roll, pitch: -store.packet.pitch, yaw: store.packet.yaw, lidAngle: store.packet.lidAngle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SensorRow: View {
    let name: String; let detail: String; let live: Bool
    var body: some View {
        HStack { Circle().fill(live ? .green : .orange).frame(width: 7, height: 7); Text(name).font(.subheadline.bold()); Spacer(); Text(detail).font(.caption).foregroundStyle(.secondary); Image(systemName: "checkmark.circle.fill").foregroundStyle(live ? .green : .secondary) }
            .padding(.vertical, 6)
    }
}

struct MotionView: View {
    @EnvironmentObject var store: SensorStore
    var body: some View {
        ScrollView { VStack(spacing: 18) {
            GlassCard("加速度计波形", subtitle: "机身的重力与微振动信号") { NeonChart(values: store.history.map(\.vibration), color: .cyan).frame(height: 300) }
            HStack(spacing: 18) {
                axisCard("X 轴", store.packet.ax, .cyan); axisCard("Y 轴", store.packet.ay, .purple); axisCard("Z 轴", store.packet.az, .pink)
            }
            GlassCard("角速度", subtitle: "单位：度/秒") { HStack { Text("X  \(store.packet.gx, specifier: "%.3f")"); Spacer(); Text("Y  \(store.packet.gy, specifier: "%.3f")"); Spacer(); Text("Z  \(store.packet.gz, specifier: "%.3f")") }.font(.title3.monospaced()).foregroundStyle(.cyan) }
        } }
    }
    private func axisCard(_ name: String, _ value: Double, _ color: Color) -> some View { GlassCard(name) { Text(String(format: "%+.6f g", value)).font(.system(size: 28, weight: .bold, design: .monospaced)).foregroundStyle(color) }.frame(maxWidth: .infinity) }
}

struct EnvironmentView: View {
    @EnvironmentObject var store: SensorStore
    private var level: (name: String, detail: String, icon: String, color: Color) {
        switch store.packet.lux {
        case ..<5: ("非常暗", "建议打开环境灯，避免屏幕与周围反差过大。", "moon.stars.fill", .indigo)
        case ..<80: ("室内弱光", "适合休闲浏览；长时间阅读建议增加环境光。", "lamp.table.fill", .purple)
        case ..<300: ("舒适室内光", "适合日常办公与阅读。", "lightbulb.led.fill", .cyan)
        case ..<1000: ("光线明亮", "环境光充足，屏幕可适当提高亮度。", "sun.max.fill", .yellow)
        default: ("强光环境", "可能靠近窗边或户外，注意屏幕反光。", "sun.max.trianglebadge.exclamationmark.fill", .orange)
        }
    }
    private var recentLux: [Double] { store.history.map(\.lux) }
    private var trend: String {
        guard recentLux.count > 12 else { return "正在学习环境变化" }
        let split = recentLux.count / 2
        let first = recentLux.prefix(split).reduce(0, +) / Double(split)
        let secondCount = recentLux.count - split
        let second = recentLux.suffix(secondCount).reduce(0, +) / Double(secondCount)
        if second > first * 1.12 { return "环境正在变亮" }
        if second < first * 0.88 { return "环境正在变暗" }
        return "光线基本稳定"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                MetricTile(icon: "sun.max.fill", title: "当前照度", value: String(format: "%.1f", store.packet.lux), unit: "lux", color: level.color)
                MetricTile(icon: level.icon, title: "环境等级", value: level.name, unit: "", color: level.color)
                MetricTile(icon: "chart.line.uptrend.xyaxis", title: "变化趋势", value: trend, unit: "", color: .cyan)
            }
            HStack(alignment: .top, spacing: 18) {
                GlassCard("环境光变化", subtitle: "实时照度曲线 · 最近 12 秒") {
                    NeonChart(values: recentLux, color: level.color).frame(height: 275)
                    HStack {
                        Text("最低 \(recentLux.min() ?? 0, specifier: "%.1f") lux")
                        Spacer()
                        Text("当前 \(store.packet.lux, specifier: "%.1f") lux").foregroundStyle(level.color)
                        Spacer()
                        Text("最高 \(recentLux.max() ?? 0, specifier: "%.1f") lux")
                    }.font(.caption.monospaced()).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)
                GlassCard("环境建议", subtitle: "根据当前照度生成") {
                    Image(systemName: level.icon).font(.system(size: 48)).foregroundStyle(level.color).shadow(color: level.color.opacity(0.45), radius: 14)
                    Text(level.name).font(.title2.bold())
                    Text(level.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Divider().opacity(0.25)
                    Label("这是环境照度参考，不是专业照度计。", systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                }.frame(width: 340)
            }
            GlassCard("传感器诊断", subtitle: "四通道原始数值，用于排查硬件变化，不代表真实光谱") {
                HStack { ForEach(Array(store.packet.lightChannels.enumerated()), id: \.offset) { index, value in VStack(spacing: 4) { Text("通道 \(index + 1)").font(.caption).foregroundStyle(.secondary); Text(value, format: .number.precision(.fractionLength(0))).font(.headline.monospaced()) }.frame(maxWidth: .infinity) } }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct TouchpadView: View {
    @StateObject private var monitor = TouchpadMonitor.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("touchCalibration.light") private var lightReference = 0.38
    @AppStorage("touchCalibration.first") private var firstReference = 0.78
    @AppStorage("touchCalibration.second") private var secondReference = 1.18
    @State private var calibrationMessage = "请按顺序记录三个阶段"
    private var rawInstantForce: Double { monitor.touches.map(\.size).max() ?? 0 }
    private var calibrationTouch: TouchPoint? { monitor.touches.max { $0.size < $1.size } }
    private func zoneIndex(_ touch: TouchPoint) -> Int {
        let column = min(2, max(0, Int(touch.x * 3)))
        let row = min(2, max(0, Int((1 - touch.y) * 3)))
        return row * 3 + column
    }
    private func zoneName(_ index: Int) -> String {
        ["左上", "中上", "右上", "左中", "中心", "右中", "左下", "中下", "右下"][min(8, max(0, index))]
    }
    private func reference(_ kind: String, zone: Int, fallback: Double) -> Double {
        let key = "touchCalibration.zone\(zone).\(kind)"
        return UserDefaults.standard.object(forKey: key) == nil ? fallback : UserDefaults.standard.double(forKey: key)
    }
    private func stagedForce(_ touch: TouchPoint) -> Double {
        let zone = zoneIndex(touch)
        let light = reference("light", zone: zone, fallback: lightReference)
        let first = reference("first", zone: zone, fallback: firstReference)
        let second = reference("second", zone: zone, fallback: secondReference)
        let firstBoundary = (light + first) / 2
        let secondBoundary = (first + second) / 2
        let raw = touch.size
        let contactFloor = max(0.05, light * 0.55)
        let hardCeiling = max(second + 0.18, second * 1.18)
        if raw < firstBoundary {
            return min(0.99, max(0, (raw - contactFloor) / max(firstBoundary - contactFloor, 0.05)))
        }
        if raw < secondBoundary {
            return min(1.99, 1.0 + (raw - firstBoundary) / max(secondBoundary - firstBoundary, 0.05))
        }
        return min(3.0, 2.0 + (raw - secondBoundary) / max(hardCeiling - secondBoundary, 0.05))
    }
    private var maxForce: Double { monitor.touches.map(stagedForce).max() ?? 0 }
    private var totalPressure: Double { monitor.touches.map(\.size).reduce(0, +) }
    private var firstClicked: Bool { maxForce >= 1.0 }
    private var deepPressed: Bool { maxForce >= 2.0 }
    private var forceStatus: String {
        if monitor.touches.isEmpty { return "未触碰" }
        if deepPressed { return "第二段深按" }
        if firstClicked { return "第一段点击" }
        return "接触"
    }
    private func captureCalibration(_ stage: Int) {
        guard let touch = calibrationTouch, rawInstantForce > 0 else {
            calibrationMessage = "请先用一根手指按住触控板"
            return
        }
        let zone = zoneIndex(touch)
        let location = zoneName(zone)
        let prefix = "touchCalibration.zone\(zone)."
        let zoneLight = reference("light", zone: zone, fallback: lightReference)
        let zoneFirst = reference("first", zone: zone, fallback: firstReference)
        switch stage {
        case 0:
            lightReference = rawInstantForce
            UserDefaults.standard.set(rawInstantForce, forKey: prefix + "light")
            calibrationMessage = "\(location)：已记录轻触 \(String(format: "%.3f", rawInstantForce))"
        case 1:
            guard rawInstantForce > zoneLight else { calibrationMessage = "\(location)：第一段必须比轻触更大"; return }
            firstReference = rawInstantForce
            UserDefaults.standard.set(rawInstantForce, forKey: prefix + "first")
            calibrationMessage = "\(location)：已记录第一段 \(String(format: "%.3f", rawInstantForce))"
        default:
            guard rawInstantForce > zoneFirst else { calibrationMessage = "\(location)：第二段必须比第一段更大"; return }
            secondReference = rawInstantForce
            UserDefaults.standard.set(rawInstantForce, forKey: prefix + "second")
            calibrationMessage = "\(location)：三点校准完成"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                MetricTile(icon: "hand.point.up.left.fill", title: "实时手指", value: "\(monitor.touches.count)", unit: "个", color: .cyan)
                MetricTile(icon: "speedometer", title: "数据刷新", value: "\(monitor.frameRate)", unit: "FPS", color: .purple)
                MetricTile(icon: "arrow.down.to.line.compact", title: "Force Touch 阶段", value: forceStatus, unit: "", color: deepPressed ? .pink : (firstClicked ? .purple : .cyan))
            }
            GeometryReader { available in
                HStack(alignment: .top, spacing: 18) {
                    GlassCard("触控板实时触点", subtitle: "位置、接触面积与 Force Touch 压力") {
                        GeometryReader { geo in
                            ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(LinearGradient(colors: [Color.cyan.opacity(0.055), Color.purple.opacity(0.055)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            RoundedRectangle(cornerRadius: 24).stroke(Color.cyan.opacity(0.35), lineWidth: 2)
                            Path { path in
                                for column in 1..<6 { let x = geo.size.width * CGFloat(column) / 6; path.move(to: .init(x: x, y: 0)); path.addLine(to: .init(x: x, y: geo.size.height)) }
                                for row in 1..<4 { let y = geo.size.height * CGFloat(row) / 4; path.move(to: .init(x: 0, y: y)); path.addLine(to: .init(x: geo.size.width, y: y)) }
                            }.stroke(colorScheme == .dark ? Color.white.opacity(0.045) : Color.black.opacity(0.09), lineWidth: 1)
                            if monitor.touches.isEmpty {
                                VStack(spacing: 11) { Image(systemName: monitor.available ? "hand.point.up.left" : "exclamationmark.triangle").font(.system(size: 42)).foregroundStyle(monitor.available ? .cyan : .orange); Text(monitor.status).foregroundStyle(.secondary) }
                            }
                            ForEach(monitor.touches) { touch in
                                let force = stagedForce(touch)
                                let intensity = min(max(force / 3.0, 0.18), 1)
                                let diameter = max(34, min(105, touch.major * 5.5))
                                ZStack {
                                    Circle().fill(Color.cyan.opacity(0.12 + intensity * 0.3)).blur(radius: 10)
                                    Circle().stroke(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                                    VStack(spacing: 1) { Text("\(touch.id)").font(.caption.bold()); Text(String(format: "%.2f", force)).font(.caption2.monospaced()) }
                                }
                                .frame(width: diameter, height: diameter)
                                .shadow(color: .cyan.opacity(intensity), radius: 18)
                                .position(x: geo.size.width * touch.x, y: geo.size.height * (1 - touch.y))
                            }
                            }
                        }
                    }
                    .frame(width: max(420, available.size.width - 378), height: available.size.height)
                    VStack(spacing: 14) {
                        GlassCard("Force Touch 按压传感器", subtitle: "0–1 接触 · 1–2 第一段 · 2–3 第二段") {
                            HStack(spacing: 18) {
                                CircularGauge(value: maxForce, maxValue: 3, title: "三段按压", display: String(format: "%.2f", maxForce), color: deepPressed ? .pink : (firstClicked ? .purple : .cyan))
                                    .frame(width: 128, height: 128)
                                VStack(alignment: .leading, spacing: 9) {
                                    Label(forceStatus, systemImage: deepPressed ? "arrow.down.circle.fill" : "hand.tap")
                                        .foregroundStyle(deepPressed ? .pink : (firstClicked ? .purple : .cyan)).bold()
                                    Text("三段按压值  \(maxForce, specifier: "%.3f") / 3").font(.caption.monospaced())
                                    Text("瞬时力度合计  \(totalPressure, specifier: "%.2f")").font(.caption.monospaced())
                                }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("九宫格分区校准 · 当前 \(calibrationTouch.map { zoneName(zoneIndex($0)) } ?? "无触点")").font(.caption.bold()).foregroundStyle(.secondary)
                                HStack(spacing: 6) {
                                    Button("记录轻触") { captureCalibration(0) }
                                    Button("记录第一段") { captureCalibration(1) }
                                    Button("记录第二段") { captureCalibration(2) }
                                }.buttonStyle(.bordered).controlSize(.small)
                                Text(calibrationMessage).font(.caption2).foregroundStyle(.cyan).lineLimit(2)
                                Text("在每个需要校准的区域依次记录三个阶段。").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: 282)
                        GlassCard("触点数据", subtitle: "\(monitor.status) · 最多显示 10 指") {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    if monitor.touches.isEmpty { Text("把手指放在触控板上查看实时数据。").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 120) }
                                    ForEach(monitor.touches.prefix(10)) { touch in
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack { Text("手指 #\(touch.id)").bold(); Spacer(); Text("\(stagedForce(touch), specifier: "%.3f") / 3").foregroundStyle(stagedForce(touch) >= 2 ? .pink : (stagedForce(touch) >= 1 ? .purple : .cyan)) }
                                            Text("X \(touch.x, specifier: "%.3f")   Y \(touch.y, specifier: "%.3f")   \(touch.major, specifier: "%.1f")×\(touch.minor, specifier: "%.1f") mm").font(.caption2.monospaced()).foregroundStyle(.cyan)
                                        }.padding(9).background(colorScheme == .dark ? Color.white.opacity(0.045) : Color.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }.frame(width: 360, height: available.size.height)
                }
            }
            .frame(minHeight: 440)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DeviceView: View {
    @EnvironmentObject var store: SensorStore
    private var fanValue: String {
        guard let fans = store.packet.fanRPM else { return "检测中" }
        guard !fans.isEmpty else { return store.packet.fanAvailable == false ? "不可读取" : "0 RPM" }
        if fans.count == 1 { return "\(Int(fans[0])) RPM" }
        return fans.map { "\(Int($0))" }.joined(separator: " / ") + " RPM"
    }
    private var fanDetail: String {
        guard let fans = store.packet.fanRPM, !fans.isEmpty else { return "SMC 实时采样" }
        return fans.count > 1 ? "\(fans.count) 个风扇 · 按左/右顺序" : "1 个风扇"
    }
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
            DeviceStatusCard(title: "电池", icon: "battery.75percent", value: store.batteryPercent, detail: store.powerSource, color: .green)
            DeviceStatusCard(title: "热状态", icon: "thermometer.medium", value: store.thermalState, detail: "macOS 系统热管理级别", color: store.thermalState == "正常" ? .cyan : .orange)
            DeviceStatusCard(title: "风扇转速", icon: "fan.fill", value: fanValue, detail: fanDetail, color: .cyan)
            DeviceStatusCard(title: "运行时间", icon: "clock.arrow.circlepath", value: store.uptime, detail: "自上次开机", color: .purple)
            DeviceStatusCard(title: "传感器连接", icon: "sensor.tag.radiowaves.forward.fill", value: store.connected ? "LIVE" : "OFFLINE", detail: store.connected ? "实时数据流已连接" : "等待底层传感器", color: store.connected ? .green : .orange)
            DeviceStatusCard(title: "安全与隐私", icon: "lock.shield.fill", value: "本地模式", detail: "无账号 · 无云同步 · 无跟踪", color: .green)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct DeviceStatusCard: View {
    let title: String
    let icon: String
    let value: String
    let detail: String
    let color: Color
    var body: some View {
        GlassCard(title) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.11))
                    Image(systemName: icon).font(.system(size: 25, weight: .medium)).foregroundStyle(color)
                }.frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 7) {
                    Text(value).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.62)
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
    }
}

struct HeartbeatView: View {
    @EnvironmentObject var store: SensorStore
    var body: some View { HStack(alignment: .top, spacing: 18) {
        GlassCard("弹道心动图 BCG", subtitle: "通过手腕传入机身的微振动估算") {
            HStack { Image(systemName: "heart.fill").font(.system(size: 58)).foregroundStyle(.pink).symbolEffect(.pulse, isActive: store.connected); VStack(alignment: .leading) { Text(store.packet.bpm > 0 ? String(format: "%.1f", store.packet.bpm) : "--").font(.system(size: 64, weight: .bold, design: .rounded)); Text("BPM · 算法推算").foregroundStyle(.secondary) } }
            NeonChart(values: store.history.map(\.bpm), color: .pink).frame(height: 220)
        }.frame(maxWidth: .infinity)
        GlassCard("可信度") { CircularGauge(value: store.packet.confidence, maxValue: 100, title: "CONFIDENCE", display: "\(Int(store.packet.confidence))%", color: store.packet.confidence > 65 ? .green : .orange).frame(width: 230, height: 230); Text("将双手腕静放在触控板两侧 10–20 秒。不要打字或触碰桌面。").font(.caption).foregroundStyle(.secondary); Label("非医疗测量", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }.frame(width: 320)
    } }
}

struct RecordingView: View {
    @EnvironmentObject var store: SensorStore
    @State private var exportMessage = ""
    var body: some View { GlassCard("传感器会话录制", subtitle: "所有实时字段保存为 CSV") {
        HStack(spacing: 16) {
            Button { store.toggleRecording() } label: { Label(store.isRecording ? "停止录制" : "开始录制", systemImage: store.isRecording ? "stop.fill" : "record.circle").frame(width: 140).padding(.vertical, 10) }.buttonStyle(.borderedProminent).tint(store.isRecording ? .red : .cyan)
            Button { if let url = store.exportCSV() { NSWorkspace.shared.activateFileViewerSelecting([url]); exportMessage = "已导出到下载文件夹" } } label: { Label("导出 CSV", systemImage: "square.and.arrow.up").padding(.vertical, 10) }.buttonStyle(.bordered).disabled(store.recorded.isEmpty)
        }
        Text("已捕获 \(store.recorded.count) 个数据包").font(.title2.monospaced()).foregroundStyle(store.isRecording ? .red : .cyan)
        if !exportMessage.isEmpty { Text(exportMessage).foregroundStyle(.green) }
        Spacer()
    }.frame(maxWidth: .infinity, maxHeight: .infinity) }
}
