import SwiftUI

struct FleetSummary {
    var reachable: Int
    var total: Int
    var cpuMax: (pct: Double, profile: Profile)?
    var memMax: (pct: Double, profile: Profile)?
    var gpuMax: (pct: Double, profile: Profile, gpuIndex: Int)?

    static func from(profiles: [Profile], snapshots: [UUID: MetricsSnapshot]) -> FleetSummary {
        var summary = FleetSummary(reachable: 0, total: profiles.count)
        for p in profiles {
            guard let snap = snapshots[p.id], snap.reachable else { continue }
            summary.reachable += 1
            if summary.cpuMax == nil || snap.cpu.utilizationPct > (summary.cpuMax?.pct ?? -1) {
                summary.cpuMax = (snap.cpu.utilizationPct, p)
            }
            if summary.memMax == nil || snap.memory.utilizationPct > (summary.memMax?.pct ?? -1) {
                summary.memMax = (snap.memory.utilizationPct, p)
            }
            if let busiest = snap.gpus.max(by: { $0.utilizationPct < $1.utilizationPct }) {
                if summary.gpuMax == nil || busiest.utilizationPct > (summary.gpuMax?.pct ?? -1) {
                    summary.gpuMax = (busiest.utilizationPct, p, busiest.index)
                }
            }
        }
        return summary
    }
}

struct OverviewView: View {
    @Bindable var state: AppState

    var body: some View {
        let summary = FleetSummary.from(profiles: state.profiles, snapshots: state.snapshots)
        VStack(alignment: .leading, spacing: 8) {
            summaryStrip(summary)
            VStack(spacing: 4) {
                ForEach(state.profiles) { profile in
                    OverviewRow(
                        profile: profile,
                        snapshot: state.snapshots[profile.id],
                        history: state.history[profile.id],
                        onTap: { state.activeProfileID = profile.id }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func summaryStrip(_ s: FleetSummary) -> some View {
        HStack(spacing: 6) {
            summaryStat(
                title: "SERVERS",
                value: "\(s.reachable)/\(s.total)",
                tint: s.reachable == s.total ? .secondary : Palette.danger
            )
            summaryStat(
                title: "CPU MAX",
                value: s.cpuMax.map { "\(Int($0.pct))%" } ?? "—",
                tint: tint(forPct: s.cpuMax?.pct)
            )
            summaryStat(
                title: "MEM MAX",
                value: s.memMax.map { "\(Int($0.pct))%" } ?? "—",
                tint: tint(forPct: s.memMax?.pct)
            )
            summaryStat(
                title: "GPU MAX",
                value: s.gpuMax.map { "\(Int($0.pct))%" } ?? "—",
                tint: tint(forPct: s.gpuMax?.pct)
            )
        }
    }

    private func summaryStat(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func tint(forPct pct: Double?) -> Color {
        guard let pct else { return .secondary }
        switch pct {
        case ..<60: return .primary
        case ..<85: return Palette.warn
        default:    return Palette.danger
        }
    }
}

// MARK: - Per-server row

struct OverviewRow: View {
    let profile: Profile
    let snapshot: MetricsSnapshot?
    let history: MetricsHistory?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                head
                if let snap = snapshot, snap.reachable {
                    bars(snap: snap)
                    footer(snap: snap)
                } else if let snap = snapshot {
                    if let err = snap.lastError {
                        Text(err)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Palette.danger)
                            .lineLimit(2)
                    }
                } else {
                    Text("polling…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverTip(enabled: hasHistory) {
            if let history { HistoryTipBuilder.overview(history: history, profile: profile) }
        }
    }

    private var head: some View {
        HStack(spacing: 6) {
            statusDot
            Text(profile.name)
                .font(.system(size: 12, weight: .semibold))
            Text(profile.sshHost)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(rightSide)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 7, height: 7)
    }

    private var statusColor: Color {
        guard let snap = snapshot else { return Palette.muted }
        if !snap.reachable { return Palette.danger }
        let ageSec = Date().timeIntervalSince(snap.timestamp)
        if ageSec > Double(profile.pollIntervalSec) * 2 { return Palette.warn }
        return Palette.ok
    }

    private var rightSide: String {
        guard let snap = snapshot else { return "—" }
        if !snap.reachable { return "⚠ unreachable" }
        let ageSec = Int(Date().timeIntervalSince(snap.timestamp))
        return "\(ageSec)s ago"
    }

    @ViewBuilder
    private func bars(snap: MetricsSnapshot) -> some View {
        let busiest = snap.gpus.max(by: { $0.utilizationPct < $1.utilizationPct })
        VStack(spacing: 4) {
            miniBar(label: "CPU", pct: snap.cpu.utilizationPct)
            miniBar(label: "MEM", pct: snap.memory.utilizationPct)
            miniBar(label: "GPU", pct: busiest?.utilizationPct ?? 0, dimmed: busiest == nil)
        }
    }

    private func miniBar(label: String, pct: Double, dimmed: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)
            ProgressView(value: min(max(pct, 0), 100), total: 100)
                .progressViewStyle(.linear)
                .tint(barColor(pct: pct, dimmed: dimmed))
            Text(dimmed ? "—" : "\(Int(pct))%")
                .font(.system(size: 10, design: .monospaced))
                .frame(width: 34, alignment: .trailing)
                .foregroundStyle(dimmed ? .secondary : .primary)
        }
    }

    private func barColor(pct: Double, dimmed: Bool) -> Color {
        if dimmed { return Palette.muted }
        return Palette.threshold(pct)
    }

    @ViewBuilder
    private func footer(snap: MetricsSnapshot) -> some View {
        let gpuCount = snap.gpus.count
        let modelName = uniqueModelName(in: snap.gpus)
        let busiest = snap.gpus.max(by: { $0.utilizationPct < $1.utilizationPct })
        HStack(spacing: 6) {
            if gpuCount > 0 {
                Text(gpuCount > 1 ? "\(gpuCount)× \(modelName)" : modelName)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
            } else {
                Text("no GPU")
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
            if let g = busiest {
                if let p = g.powerW {
                    Text(String(format: "GPU %d · %d°C · %.0f W", g.index, Int(g.temperatureC), p))
                } else {
                    Text(String(format: "GPU %d · %d°C", g.index, Int(g.temperatureC)))
                }
            }
            Spacer(minLength: 0)
            Text("poll \(profile.pollIntervalSec)s")
        }
        .font(.system(size: 9.5, design: .monospaced))
        .foregroundStyle(.secondary)
    }

    private func uniqueModelName(in gpus: [GPUStats]) -> String {
        let names = Set(gpus.map(\.name))
        if names.count == 1, let n = names.first { return n }
        return "GPUs"
    }

    private var hasHistory: Bool {
        (history?.reachableSamples.count ?? 0) >= 1
    }
}
