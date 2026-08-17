import AppKit
import SwiftUI

extension View {
    /// Keeps the enclosing `MenuBarExtra` window exactly as tall as this view.
    func menuBarWindowAutoSize() -> some View {
        modifier(MenuBarWindowAutoSize())
    }
}

/// Drives the height of the `.menuBarExtraStyle(.window)` panel from its content.
///
/// AppKit sizes that panel when the popover first opens and grows it when the
/// content grows, but it never shrinks it back. Switching from the tall Overview
/// tab to a single-server tab therefore left the panel at the old height with the
/// content floating inside a transparent gap. Measuring the content at its ideal
/// height and pushing that onto the window fixes both directions.
private struct MenuBarWindowAutoSize: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Take the ideal height instead of stretching to the window, or the
            // measurement below would just echo the stale window height back.
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { proxy in
                    WindowHeightSetter(contentHeight: proxy.size.height)
                        .frame(width: 0, height: 0)
                }
            }
            // Until the resize lands the content would otherwise sit centred in
            // the still-too-tall panel — the very thing this fixes. The cap is
            // the screen rather than `.infinity` so that however SwiftUI sizes
            // the panel itself, it can never ask for more than fits.
            .frame(maxHeight: Self.screenHeight, alignment: .top)
    }

    private static var screenHeight: CGFloat {
        (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.height ?? 800
    }
}

private struct WindowHeightSetter: NSViewRepresentable {
    let contentHeight: CGFloat

    func makeNSView(context: Context) -> NSView { PassthroughView() }

    func updateNSView(_ view: NSView, context: Context) {
        // The view has no window during the first layout pass, and resizing in
        // the middle of a SwiftUI layout re-enters it, so hand this to the next
        // runloop turn — retrying briefly for the very first open, where the
        // panel may not have adopted the hosting view yet.
        let height = contentHeight
        context.coordinator.run {
            for _ in 0..<10 {
                if Task.isCancelled { return }
                if let window = view.window {
                    Self.apply(height: height, to: window)
                    return
                }
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        private var pending: Task<Void, Never>?

        /// Only the newest measurement matters; drop any still-waiting one.
        func run(_ body: @escaping @MainActor () async -> Void) {
            pending?.cancel()
            pending = Task { @MainActor in await body() }
        }
    }

    private static func apply(height: CGFloat, to window: NSWindow) {
        guard height > 1 else { return }
        let content = window.contentRect(forFrameRect: window.frame)
        var target = height
        if let screen = window.screen ?? NSScreen.main {
            // AppKit shoves a panel taller than the screen back into view, which
            // would tear it away from the status item; clamp instead.
            target = min(target, screen.visibleFrame.height)
        }
        guard abs(content.height - target) > 0.5 else { return }
        var newContent = content
        newContent.size.height = target
        newContent.origin.y = content.maxY - target // keep the top edge put
        window.setFrame(window.frameRect(forContentRect: newContent), display: true)
        window.invalidateShadow()
    }

    /// A plain `NSView` would swallow clicks aimed at the SwiftUI content behind
    /// it, even at zero size.
    private final class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
