import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview = "总览"
    case pose = "实时姿态"
    case motion = "运动与振动"
    case environment = "环境"
    case touchpad = "触控板"
    case device = "设备状态"
    case heartbeat = "心率实验室"
    case recording = "记录"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: "sparkles"
        case .pose: "view.3d"
        case .motion: "waveform.path.ecg.rectangle"
        case .environment: "sun.max.fill"
        case .touchpad: "hand.tap.fill"
        case .device: "macbook.gen2"
        case .heartbeat: "heart.fill"
        case .recording: "record.circle"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: SensorStore
    @State private var selection: AppSection = .overview

    var body: some View {
        ZStack {
            NebulaBackground()
            HStack(spacing: 0) {
                Sidebar(selection: $selection)
                VStack(spacing: 0) {
                    TopBar(section: selection)
                    Group {
                        switch selection {
                        case .overview: OverviewView()
                        case .pose: RealtimePoseView()
                        case .motion: MotionView()
                        case .environment: EnvironmentView()
                        case .touchpad: TouchpadView()
                        case .device: DeviceView()
                        case .heartbeat: HeartbeatView()
                        case .recording: RecordingView()
                        }
                    }
                    .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(.primary)
    }
}

struct NebulaBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(red: 0.025, green: 0.035, blue: 0.075) : Color(red: 0.91, green: 0.95, blue: 0.98))
            Circle().fill(Color.cyan.opacity(colorScheme == .dark ? 0.13 : 0.18)).frame(width: 620).blur(radius: 120).offset(x: 420, y: -360)
            Circle().fill(Color.purple.opacity(colorScheme == .dark ? 0.16 : 0.12)).frame(width: 520).blur(radius: 130).offset(x: -430, y: 350)
            LinearGradient(colors: [.clear, colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.28)], startPoint: .top, endPoint: .bottom)
        }.ignoresSafeArea()
    }
}

struct Sidebar: View {
    @Binding var selection: AppSection
    @EnvironmentObject var store: SensorStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearance.lightMode") private var lightMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "sensor.tag.radiowaves.forward.fill").font(.title2)
                }.frame(width: 46, height: 46).shadow(color: .cyan.opacity(0.45), radius: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SENSOR").font(.caption.bold()).tracking(3).foregroundStyle(.cyan)
                    Text("NEBULA").font(.title3.bold()).tracking(1)
                }
            }.padding(.bottom, 22)

            ForEach(AppSection.allCases) { item in
                Button {
                    withAnimation(.snappy) { selection = item }
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: item.icon).frame(width: 22)
                        Text(item.rawValue).font(.system(size: 14, weight: .medium))
                        Spacer()
                        if selection == item { Circle().fill(.cyan).frame(width: 6, height: 6).shadow(color: .cyan, radius: 7) }
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .background(selection == item ? (colorScheme == .dark ? Color.white.opacity(0.09) : Color.cyan.opacity(0.13)) : .clear, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { if selection == item { RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.28)) } }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .foregroundStyle(selection == item ? Color.primary : Color.secondary)
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { lightMode.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: lightMode ? "moon.stars.fill" : "sun.max.fill")
                        .foregroundStyle(lightMode ? .indigo : .yellow)
                    Text(lightMode ? "切换夜间模式" : "切换日间模式").font(.caption.bold())
                    Spacer()
                }
                .padding(.horizontal, 13).frame(height: 40)
                .contentShape(Rectangle())
                .background(colorScheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
            HStack(spacing: 9) {
                Circle().fill(store.connected ? .green : .orange).frame(width: 8, height: 8).shadow(color: store.connected ? .green : .orange, radius: 6)
                VStack(alignment: .leading) {
                    Text(store.connected ? "传感器已连接" : "等待传感器")
                    Text(store.connected ? "实时数据流" : "请从启动器运行")
                        .font(.caption2).foregroundStyle(.secondary)
                }.font(.caption)
            }.padding(14).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(22)
        .frame(width: 238)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(colorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.34))
        .overlay(alignment: .trailing) { Rectangle().fill(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.10)).frame(width: 1) }
    }
}

struct TopBar: View {
    let section: AppSection
    @EnvironmentObject var store: SensorStore
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(section.rawValue).font(.title2.bold())
                Text("MacBook Pro · Apple Silicon · 本地隐私模式").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Label(store.connected ? "LIVE" : "OFFLINE", systemImage: store.connected ? "dot.radiowaves.left.and.right" : "bolt.slash")
                .font(.caption.bold()).foregroundStyle(store.connected ? .green : .orange)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background((store.connected ? Color.green : Color.orange).opacity(0.1), in: Capsule())
            Text(Date.now, style: .time).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 26).frame(height: 76)
        .background(.ultraThinMaterial.opacity(0.45))
        .overlay(alignment: .bottom) { Rectangle().fill(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.10)).frame(height: 1) }
    }
}
