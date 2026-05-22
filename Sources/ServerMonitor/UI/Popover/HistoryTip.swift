import SwiftUI

struct HistorySeries {
    var title: String
    var values: [Double]
    var range: ClosedRange<Double>?
    var tint: Color
    var nowDisplay: String
    /// Format used for min/avg/max chips.
    var fmt: (Double) -> String
}

struct HistoryTip: View {
    let title: String
    let series: [HistorySeries]
    let sampleCount: Int
    let oldestAge: TimeInterval?
    let footer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                if let last = series.first?.nowDisplay {
                    Text(last)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tint)
                }
            }

            if series.count == 1, let s = series.first {
                singleSeries(s)
            } else {
                ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                    stackedRow(s)
                }
                axis
            }

            if let footer {
                Divider()
                Text(footer)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    @ViewBuilder
    private func singleSeries(_ s: HistorySeries) -> some View {
        Sparkline(values: s.values, tint: s.tint, range: s.range, filled: true)
            .frame(height: 56)
        axis
        statsStrip(s)
    }

    @ViewBuilder
    private func stackedRow(_ s: HistorySeries) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(s.title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(s.nowDisplay)
                    .font(.system(size: 10, design: .monospaced))
            }
            Sparkline(values: s.values, tint: s.tint, range: s.range, filled: false)
                .frame(height: 30)
        }
    }

    private var axis: some View {
        HStack {
            ForEach(["−5m", "−4m", "−3m", "−2m", "−1m", "now"], id: \.self) { t in
                Text(t)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                if t != "now" { Spacer() }
            }
        }
    }

    @ViewBuilder
    private func statsStrip(_ s: HistorySeries) -> some View {
        let vals = s.values
        let mn = vals.min() ?? 0
        let mx = vals.max() ?? 0
        let avg = vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
        HStack(spacing: 6) {
            statChip("min", s.fmt(mn))
            statChip("avg", s.fmt(avg))
            statChip("max", s.fmt(mx))
        }
    }

    private func statChip(_ k: String, _ v: String) -> some View {
        VStack(spacing: 1) {
            Text(k.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(v)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Builders from MetricsHistory

enum HistoryTipBuilder {
    static func cpu(history: MetricsHistory, now: CPUStats) -> HistoryTip {
        let samples = history.reachableSamples
        let vals = samples.map { $0.cpu.utilizationPct }
        return HistoryTip(
            title: "CPU · last 5 min",
            series: [
                HistorySeries(
                    title: "CPU",
                    values: vals,
                    range: 0...100,
                    tint: Palette.accent,
                    nowDisplay: "\(Int(now.utilizationPct))%",
                    fmt: { "\(Int($0))%" }
                )
            ],
            sampleCount: vals.count,
            oldestAge: samples.first.map { Date().timeIntervalSince($0.timestamp) },
            footer: footer(for: history, extra: nil)
        )
    }

    static func memory(history: MetricsHistory, now: MemoryStats) -> HistoryTip {
        let samples = history.reachableSamples
        let vals = samples.map { $0.memory.utilizationPct }
        let totalGB = Double(now.totalBytes) / 1_073_741_824
        let usedGB = Double(now.usedBytes) / 1_073_741_824
        return HistoryTip(
            title: "MEM · last 5 min",
            series: [
                HistorySeries(
                    title: "MEM",
                    values: vals,
                    range: 0...100,
                    tint: Palette.accent2,
                    nowDisplay: "\(Int(now.utilizationPct))%",
                    fmt: { "\(Int($0))%" }
                )
            ],
            sampleCount: vals.count,
            oldestAge: samples.first.map { Date().timeIntervalSince($0.timestamp) },
            footer: footer(for: history, extra: String(format: "%.1f / %.0f GB now", usedGB, totalGB))
        )
    }

    static func gpu(history: MetricsHistory, index: Int, now: GPUStats) -> HistoryTip {
        let samples = history.reachableSamples
        let util = samples.compactMap { snap -> Double? in
            snap.gpus.first(where: { $0.index == index })?.utilizationPct
        }
        let vram = samples.compactMap { snap -> Double? in
            guard let g = snap.gpus.first(where: { $0.index == index }) else { return nil }
            return g.memUtilizationPct
        }
        let temp = samples.compactMap { snap -> Double? in
            snap.gpus.first(where: { $0.index == index })?.temperatureC
        }
        let title = "GPU \(index) · \(now.name) · last 5 min"
        let peakUtil = util.max() ?? 0
        let peakTemp = temp.max() ?? 0
        return HistoryTip(
            title: title,
            series: [
                HistorySeries(
                    title: "util",
                    values: util,
                    range: 0...100,
                    tint: Palette.accent,
                    nowDisplay: "\(Int(now.utilizationPct))%",
                    fmt: { "\(Int($0))%" }
                ),
                HistorySeries(
                    title: "vram",
                    values: vram,
                    range: 0...100,
                    tint: Palette.accent2,
                    nowDisplay: String(format: "%.1f / %.0f GB",
                                       Double(now.memUsedMB) / 1024,
                                       Double(now.memTotalMB) / 1024),
                    fmt: { "\(Int($0))%" }
                ),
                HistorySeries(
                    title: "temp",
                    values: temp,
                    range: nil,
                    tint: Palette.warn,
                    nowDisplay: "\(Int(now.temperatureC))°C",
                    fmt: { "\(Int($0))°C" }
                )
            ],
            sampleCount: util.count,
            oldestAge: samples.first.map { Date().timeIntervalSince($0.timestamp) },
            footer: String(format: "peak util %d%% · peak temp %d°C · %d samples",
                           Int(peakUtil), Int(peakTemp), util.count)
        )
    }

    static func overview(history: MetricsHistory, profile: Profile) -> HistoryTip {
        let samples = history.reachableSamples
        let cpu = samples.map { $0.cpu.utilizationPct }
        let mem = samples.map { $0.memory.utilizationPct }
        let gpu = samples.map { snap -> Double in
            snap.gpus.map(\.utilizationPct).max() ?? 0
        }
        let nowCPU = cpu.last ?? 0
        let nowMEM = mem.last ?? 0
        let nowGPU = gpu.last ?? 0
        return HistoryTip(
            title: "\(profile.name) · last 5 min",
            series: [
                HistorySeries(
                    title: "cpu",
                    values: cpu,
                    range: 0...100,
                    tint: Palette.accent,
                    nowDisplay: "\(Int(nowCPU))%",
                    fmt: { "\(Int($0))%" }
                ),
                HistorySeries(
                    title: "mem",
                    values: mem,
                    range: 0...100,
                    tint: Palette.accent2,
                    nowDisplay: "\(Int(nowMEM))%",
                    fmt: { "\(Int($0))%" }
                ),
                HistorySeries(
                    title: "gpu max",
                    values: gpu,
                    range: 0...100,
                    tint: Palette.warn,
                    nowDisplay: "\(Int(nowGPU))%",
                    fmt: { "\(Int($0))%" }
                )
            ],
            sampleCount: samples.count,
            oldestAge: samples.first.map { Date().timeIntervalSince($0.timestamp) },
            footer: "\(samples.count) samples · \(profile.sshHost)"
        )
    }

    private static func footer(for history: MetricsHistory, extra: String?) -> String {
        var parts: [String] = ["\(history.reachableSamples.count) samples"]
        if let extra { parts.append(extra) }
        return parts.joined(separator: " · ")
    }
}
