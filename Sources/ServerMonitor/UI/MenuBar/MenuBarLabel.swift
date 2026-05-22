import SwiftUI
import AppKit

struct MenuBarLabel: View {
    let state: AppState

    var body: some View {
        if let profile = sourceProfile {
            let snapshot = state.snapshots[profile.id]
            Image(nsImage: renderBars(snapshot: snapshot))
        } else {
            Image(systemName: "server.rack")
        }
    }

    /// Source for the bars: the active profile if any, otherwise the first
    /// configured profile. Returns nil only when no profiles are configured.
    private var sourceProfile: Profile? {
        state.activeProfile ?? state.profiles.first
    }

    @MainActor
    private func renderBars(snapshot: MetricsSnapshot?) -> NSImage {
        let view = GPUBarsView(
            gpu0: gpuPct(snapshot: snapshot, index: 0),
            gpu1: gpuPct(snapshot: snapshot, index: 1)
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let size = NSSize(width: GPUBarsView.totalWidth, height: GPUBarsView.totalHeight)
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
