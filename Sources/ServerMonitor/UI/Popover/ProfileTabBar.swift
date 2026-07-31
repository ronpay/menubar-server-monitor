import SwiftUI

struct ProfileTabBar: View {
    let profiles: [Profile]
    let activeID: UUID?
    let showOverview: Bool
    let onSelect: (UUID?) -> Void

    var body: some View {
        WrapLayout(spacing: 4, lineSpacing: 4) {
            if showOverview {
                tab(
                    title: "Overview",
                    icon: "square.grid.2x2",
                    isActive: activeID == nil,
                    action: { onSelect(nil) }
                )
            }
            ForEach(profiles) { profile in
                tab(
                    title: profile.name,
                    icon: profile.iconSymbol,
                    isActive: profile.id == activeID,
                    action: { onSelect(profile.id) }
                )
            }
        }
    }

    private func tab(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: Self.maxTabLabelWidth)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.25) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .medium))
        .help(title)
    }

    /// Keeps one long server name from claiming a whole row.
    private static let maxTabLabelWidth: CGFloat = 130
}

/// Lays subviews out left to right and wraps to the next line when the
/// proposed width runs out.
///
/// The popover is a fixed 380pt wide, so a horizontally scrolling tab strip
/// pushed every tab past the fourth off the right edge — unreachable without a
/// horizontal-scroll gesture. Wrapping keeps every server tab on screen and
/// clickable no matter how many are configured.
struct WrapLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let lines = lines(maxWidth: maxWidth, subviews: subviews)
        let height = lines.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, lines.count - 1))
        let widest = lines.map(\.width).max() ?? 0
        return CGSize(width: min(widest, maxWidth), height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        var y = bounds.minY
        for line in lines(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private func lines(maxWidth: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = []
        var current = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let widthIfAppended = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && widthIfAppended > maxWidth {
                lines.append(current)
                current = Line(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = widthIfAppended
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { lines.append(current) }
        return lines
    }
}
