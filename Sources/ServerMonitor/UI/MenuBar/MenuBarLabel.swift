import SwiftUI
import AppKit

@MainActor
struct MenuBarLabel: View {
    let state: AppState

    var body: some View {
        if let profile = sourceProfile {
            let snapshot = state.snapshots[profile.id]
            Image(nsImage: renderWidget(barsSnapshot: snapshot, fleet: fleetSnapshots))
        } else {
            Image(systemName: "server.rack")
        }
    }

    /// Source for the bars: the active profile if any, otherwise the first
    /// configured profile. Returns nil only when no profiles are configured.
    private var sourceProfile: Profile? {
        state.activeProfile ?? state.profiles.first
    }

    /// Latest snapshot for the first three configured servers, in list order,
    /// regardless of which profile is active. Drives the fleet dot matrix.
    /// Reading these here registers them as observation dependencies, so the
    /// menu bar refreshes whenever any of the first three servers polls.
    private var fleetSnapshots: [MetricsSnapshot?] {
        state.profiles.prefix(DotMatrixView.maxRows).map { state.snapshots[$0.id] }
    }

    @MainActor
    private func renderWidget(barsSnapshot: MetricsSnapshot?, fleet: [MetricsSnapshot?]) -> NSImage {
        let view = MenuBarWidgetView(
            gpu0: gpuPct(snapshot: barsSnapshot, index: 0),
            gpu1: gpuPct(snapshot: barsSnapshot, index: 1),
            fleet: fleet
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let size = NSSize(width: MenuBarWidgetView.totalWidth, height: MenuBarWidgetView.totalHeight)
        guard let cg = renderer.cgImage else {
            return NSImage(size: size)
        }
        let img = NSImage(cgImage: cg, size: size)
        img.isTemplate = false
        return img
    }

    private func gpuPct(snapshot: MetricsSnapshot?, index: Int) -> Double? {
        guard let snapshot, snapshot.reachable else { return nil }
        return snapshot.gpus.first(where: { $0.index == index })?.utilizationPct
    }
}

/// The full menu-bar widget: two detailed GPU bars for the focused server on
/// the left, a hairline divider, then a 3×2 dot matrix summarizing the first
/// three servers' two GPUs on the right.
private struct MenuBarWidgetView: View {
    let gpu0: Double?
    let gpu1: Double?
    let fleet: [MetricsSnapshot?]

    static let sectionGap: CGFloat = 5
    static let dividerWidth: CGFloat = 1
    static let dividerHeight: CGFloat = 14
    static let totalHeight: CGFloat = GPUBarsView.totalHeight
    static var totalWidth: CGFloat {
        GPUBarsView.totalWidth + sectionGap + dividerWidth + sectionGap + DotMatrixView.totalWidth
    }

    var body: some View {
        HStack(spacing: Self.sectionGap) {
            GPUBarsView(gpu0: gpu0, gpu1: gpu1)
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.white.opacity(0.12))
                .frame(width: Self.dividerWidth, height: Self.dividerHeight)
            DotMatrixView(rows: fleet)
        }
        .frame(width: Self.totalWidth, height: Self.totalHeight)
    }
}

private struct GPUBarsView: View {
    let gpu0: Double?
    let gpu1: Double?

    static let barWidth: CGFloat = 9
    static let barHeight: CGFloat = 20
    static let gap: CGFloat = 3
    static let totalWidth: CGFloat = barWidth * 2 + gap
    static let totalHeight: CGFloat = barHeight

    var body: some View {
        HStack(spacing: Self.gap) {
            Bar(value: gpu0)
            Bar(value: gpu1)
        }
        .frame(width: Self.totalWidth, height: Self.totalHeight)
    }
}

private struct Bar: View {
    let value: Double?

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.22))
                .frame(width: GPUBarsView.barWidth, height: GPUBarsView.barHeight)
            if let v = value {
                let h = max(0, min(1, v / 100)) * GPUBarsView.barHeight
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Palette.threshold(v))
                    .frame(width: GPUBarsView.barWidth, height: h)
            }
        }
    }
}

// MARK: - Fleet dot matrix

/// Per-dot rendering state for the fleet matrix.
private enum DotState {
    /// Reachable GPU — colored by utilization threshold.
    case util(Double)
    /// Server reachable but this GPU index has no data (single-GPU box), or the
    /// whole server is unreachable / still polling — drawn as a hollow ring.
    case hollow
    /// No server configured for this slot — drawn as nothing.
    case empty
}

/// A 3×2 grid of dots: one row per server (first three configured), one column
/// per GPU (gpu0 / gpu1). The grid always reserves three rows so the widget
/// width and vertical centering stay stable as servers come and go.
private struct DotMatrixView: View {
    /// Latest snapshot for each of the first three servers, in list order.
    /// Fewer than three entries leaves the trailing rows empty.
    let rows: [MetricsSnapshot?]

    static let maxRows = 3
    static let columns = 2
    static let dotSize: CGFloat = 5
    static let rowGap: CGFloat = 2
    static let colGap: CGFloat = 3
    static let totalWidth: CGFloat = dotSize * CGFloat(columns) + colGap * CGFloat(columns - 1)
    static let totalHeight: CGFloat = dotSize * CGFloat(maxRows) + rowGap * CGFloat(maxRows - 1)

    var body: some View {
        Grid(horizontalSpacing: Self.colGap, verticalSpacing: Self.rowGap) {
            ForEach(0..<Self.maxRows, id: \.self) { row in
                GridRow {
                    Dot(state: state(row: row, gpuIndex: 0))
                    Dot(state: state(row: row, gpuIndex: 1))
                }
            }
        }
        .frame(width: Self.totalWidth, height: Self.totalHeight)
    }

    private func state(row: Int, gpuIndex: Int) -> DotState {
        guard row < rows.count else { return .empty }
        guard let snap = rows[row], snap.reachable else { return .hollow }
        guard let gpu = snap.gpus.first(where: { $0.index == gpuIndex }) else { return .hollow }
        return .util(gpu.utilizationPct)
    }
}

private struct Dot: View {
    let state: DotState

    var body: some View {
        let size = DotMatrixView.dotSize
        switch state {
        case .util(let v):
            Circle()
                .fill(Palette.threshold(v))
                .frame(width: size, height: size)
        case .hollow:
            Circle()
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                .frame(width: size, height: size)
        case .empty:
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
        }
    }
}
