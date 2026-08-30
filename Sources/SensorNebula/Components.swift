import SwiftUI

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.subtitle = subtitle; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
            }
            content
        }
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(LinearGradient(colors: [colorScheme == .dark ? .white.opacity(0.22) : .black.opacity(0.12), .cyan.opacity(0.1), .purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
    }
}

struct MetricTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { Image(systemName: icon).foregroundStyle(color); Spacer(); Circle().fill(color).frame(width: 5, height: 5).shadow(color: color, radius: 6) }
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value).font(.system(size: 27, weight: .semibold, design: .rounded))
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(16).background(colorScheme == .dark ? Color.white.opacity(0.045) : Color.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.09)))
    }
}

struct NeonChart: View {
    @Environment(\.colorScheme) private var colorScheme
    let values: [Double]
    var color: Color = .cyan
    var body: some View {
        GeometryReader { geo in
            let maxValue = max(values.max() ?? 1, 0.0001)
            let minValue = values.min() ?? 0
            let range = max(maxValue - minValue, 0.0001)
            ZStack {
                Path { p in
                    for row in 0...3 {
                        let y = geo.size.height * CGFloat(row) / 3
                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }.stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [4, 7]))
                if values.count > 1 {
                    Path { p in
                        for (i, value) in values.enumerated() {
                            let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                            let y = geo.size.height * (1 - CGFloat((value - minValue) / range) * 0.82 - 0.09)
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }.stroke(color.opacity(0.2), lineWidth: 9).blur(radius: 8)
                    Path { p in
                        for (i, value) in values.enumerated() {
                            let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                            let y = geo.size.height * (1 - CGFloat((value - minValue) / range) * 0.82 - 0.09)
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }.stroke(LinearGradient(colors: [color.opacity(0.5), color, colorScheme == .dark ? .white : color.opacity(0.82)], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

struct CircularGauge: View {
    @Environment(\.colorScheme) private var colorScheme
    let value: Double
    let maxValue: Double
    let title: String
    let display: String
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.10), lineWidth: 12)
            Circle().trim(from: 0, to: min(max(value / maxValue, 0), 1))
                .stroke(AngularGradient(colors: [color.opacity(0.45), color, colorScheme == .dark ? .white : color.opacity(0.78)], center: .center), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90)).shadow(color: color.opacity(0.5), radius: 9)
            VStack(spacing: 3) { Text(display).font(.system(size: 24, weight: .bold, design: .rounded)); Text(title).font(.caption).foregroundStyle(.secondary) }
        }.padding(8)
    }
}
