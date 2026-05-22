import SwiftUI

struct MetricRow: View {
    let label: String
    let detail: String?
    let pct: Double
    let trailing: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(trailing)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            ProgressView(value: min(max(pct, 0), 100), total: 100)
                .progressViewStyle(.linear)
                .tint(color(forPct: pct))
        }
    }

    private func color(forPct pct: Double) -> Color {
        Palette.threshold(pct)
    }
}

// MARK: - Hover popover wrapper

struct HoverTip<Tip: View>: ViewModifier {
    let enabled: Bool
    @ViewBuilder var tip: () -> Tip

    @State private var showTip = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onHover { hovering in
                hoverTask?.cancel()
                if hovering && enabled {
                    hoverTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        if !Task.isCancelled {
                            showTip = true
                        }
                    }
                } else {
                    showTip = false
                }
            }
            .popover(isPresented: $showTip, arrowEdge: .trailing) {
                tip()
            }
    }
}

extension View {
    func hoverTip<Tip: View>(
        enabled: Bool = true,
        @ViewBuilder _ tip: @escaping () -> Tip
    ) -> some View {
        modifier(HoverTip(enabled: enabled, tip: tip))
    }
}

// MARK: - Cards

struct CPUCard: View {
    let stats: CPUStats
    var history: MetricsHistory?

    var body: some View {
        MetricRow(
            label: "CPU",
            detail: nil,
            pct: stats.utilizationPct,
            trailing: "\(Int(stats.utilizationPct))%"
        )
        .hoverTip(enabled: hasHistory) {
            if let history { HistoryTipBuilder.cpu(history: history, now: stats) }
        }
    }

    private var hasHistory: Bool {
        (history?.reachableSamples.count ?? 0) >= 1
    }
}

struct MemoryCard: View {
    let stats: MemoryStats
    var history: MetricsHistory?

    var body: some View {
        MetricRow(
            label: "MEM",
            detail: formatBytes(stats),
            pct: stats.utilizationPct,
            trailing: "\(Int(stats.utilizationPct))%"
        )
        .hoverTip(enabled: hasHistory) {
            if let history { HistoryTipBuilder.memory(history: history, now: stats) }
        }
    }

    private func formatBytes(_ s: MemoryStats) -> String {
        let used = Double(s.usedBytes) / 1_073_741_824
        let total = Double(s.totalBytes) / 1_073_741_824
        return String(format: "%.1f / %.0f GB", used, total)
    }

    private var hasHistory: Bool {
        (history?.reachableSamples.count ?? 0) >= 1
    }
}

struct GPUCard: View {
    let gpu: GPUStats
    var history: MetricsHistory?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("GPU \(gpu.index)")
                    .font(.system(size: 12, weight: .semibold))
                Text(gpu.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(gpu.temperatureC))°C")
                if let p = gpu.powerW {
                    Text("·")
                    Text(String(format: "%.0f W", p))
                }
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)

            MetricRow(
                label: "UTIL",
                detail: nil,
                pct: gpu.utilizationPct,
                trailing: "\(Int(gpu.utilizationPct))%"
            )
            MetricRow(
                label: "MEM",
                detail: String(format: "%.1f / %.0f GB", Double(gpu.memUsedMB) / 1024, Double(gpu.memTotalMB) / 1024),
                pct: gpu.memUtilizationPct,
                trailing: "\(Int(gpu.memUtilizationPct))%"
            )
        }
        .hoverTip(enabled: hasHistory) {
            if let history {
                HistoryTipBuilder.gpu(history: history, index: gpu.index, now: gpu)
            }
        }
    }

    private var hasHistory: Bool {
        guard let history else { return false }
        return history.reachableSamples.contains { snap in
            snap.gpus.contains { $0.index == gpu.index }
        }
    }
}
