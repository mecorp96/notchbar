import SwiftUI

struct SystemMonitorView: View {
    var isHovering: Bool = false
    private var monitor: SystemMonitor { .shared }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                GaugeRing(value: monitor.cpuUsage / 100, icon: "cpu", color: colorFor(monitor.cpuUsage))
                if isHovering {
                    Text("\(Int(monitor.cpuUsage))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }

            HStack(spacing: 4) {
                GaugeRing(value: monitor.memoryPercent / 100, icon: "memorychip", color: colorFor(monitor.memoryPercent))
                if isHovering {
                    Text("\(String(format: "%.1f", monitor.memoryUsed))G")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: isHovering)
    }

    private func colorFor(_ value: Double) -> Color {
        if value < 60 { return .green }
        if value < 85 { return .yellow }
        return .red
    }
}

private struct GaugeRing: View {
    let value: Double  // 0–1
    let icon: String
    let color: Color

    @State private var animatedValue: Double = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 2)

            // Value ring — animated fill
            Circle()
                .trim(from: 0, to: animatedValue)
                .stroke(
                    color.opacity(0.85),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Icon with subtle pulse when high usage
            Image(systemName: icon)
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .scaleEffect(value > 0.85 ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: value > 0.85)
        }
        .frame(width: 18, height: 18)
        .onAppear {
            // Animate ring fill on first appearance
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(appeared ? 0 : 0.4)) {
                animatedValue = min(value, 1)
            }
            appeared = true
        }
        .onChange(of: value) { _, newValue in
            // Smooth transitions on value changes
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedValue = min(newValue, 1)
            }
        }
    }
}
