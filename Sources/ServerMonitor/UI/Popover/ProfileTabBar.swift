import SwiftUI

struct ProfileTabBar: View {
    let profiles: [Profile]
    let activeID: UUID?
    let showOverview: Bool
    let onSelect: (UUID?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
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
    }

    private func tab(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title).lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.25) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .medium))
    }
}
