import SwiftUI

struct MenuBarLabel: View {
    let state: AppState

    var body: some View {
        if let profile = state.activeProfile {
            let snapshot = state.snapshots[profile.id]
            HStack(spacing: 4) {
                Image(systemName: profile.iconSymbol)
                Text(displayText(profile: profile, snapshot: snapshot))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
        } else if !state.profiles.isEmpty {
            overviewLabel
        } else {
            Image(systemName: "server.rack")
        }
    }

    private func displayText(profile: Profile, snapshot: MetricsSnapshot?) -> String {
        guard let snapshot, snapshot.reachable else { return "—" }
        switch profile.menuBarMetric {
        case .cpu:
            return "CPU \(Int(snapshot.cpu.utilizationPct))%"
        case .memory:
            return "MEM \(Int(snapshot.memory.utilizationPct))%"
        case .gpu:
            guard let top = snapshot.gpus.max(by: { $0.utilizationPct < $1.utilizationPct }) else {
                return "GPU —"
            }
            return "GPU\(top.index) \(Int(top.utilizationPct))%"
        }
    }

    @ViewBuilder
    private var overviewLabel: some View {
        let summary = FleetSummary.from(profiles: state.profiles, snapshots: state.snapshots)
        let down = summary.total - summary.reachable
        if down > 0 && summary.reachable == 0 {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("\(down)/\(summary.total) down")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
        } else if let worst = worstStat(summary) {
            HStack(spacing: 4) {
                Image(systemName: "square.grid.2x2")
                Text(worst)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                if down > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.warn)
                }
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "square.grid.2x2")
                Text("—")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
        }
    }

    private func worstStat(_ s: FleetSummary) -> String? {
        // Pick the metric with the highest percentage; prefix with the offending profile's initial.
        var candidates: [(String, Double, Profile)] = []
        if let c = s.cpuMax { candidates.append(("CPU", c.pct, c.profile)) }
        if let m = s.memMax { candidates.append(("MEM", m.pct, m.profile)) }
        if let g = s.gpuMax { candidates.append(("GPU", g.pct, g.profile)) }
        guard let top = candidates.max(by: { $0.1 < $1.1 }) else { return nil }
        let initial = top.2.name.first.map(String.init)?.uppercased() ?? "?"
        return "\(initial)·\(top.0) \(Int(top.1))%"
    }
}
