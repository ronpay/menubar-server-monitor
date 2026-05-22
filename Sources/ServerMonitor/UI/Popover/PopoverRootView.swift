import SwiftUI

struct PopoverRootView: View {
    @Bindable var state: AppState
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if state.profiles.isEmpty {
                emptyState
            } else if let profile = state.activeProfile {
                ProfileDetailView(
                    profile: profile,
                    snapshot: state.snapshots[profile.id],
                    history: state.history[profile.id]
                )
                .padding(12)
            } else {
                OverviewView(state: state)
                    .padding(12)
            }
            Divider()
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            ProfileTabBar(
                profiles: state.profiles,
                activeID: state.activeProfileID,
                showOverview: !state.profiles.isEmpty,
                onSelect: { state.activeProfileID = $0 }
            )
            Spacer(minLength: 0)
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            if let profile = state.activeProfile {
                if let snapshot = state.snapshots[profile.id] {
                    Text(footerStatus(snapshot: snapshot, profile: profile))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("polling…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else if !state.profiles.isEmpty {
                Text(overviewFooter)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func footerStatus(snapshot: MetricsSnapshot, profile: Profile) -> String {
        let ageSec = Int(Date().timeIntervalSince(snapshot.timestamp))
        let host = profile.sshHost
        if !snapshot.reachable {
            let err = snapshot.lastError ?? "unreachable"
            return "⚠︎ \(host): \(err)"
        }
        return "updated \(ageSec)s ago · poll \(profile.pollIntervalSec)s · \(host)"
    }

    private var overviewFooter: String {
        let n = state.profiles.count
        let reachable = state.profiles.filter { state.snapshots[$0.id]?.reachable == true }.count
        let intervals = state.profiles.map(\.pollIntervalSec)
        let minInterval = intervals.min() ?? 5
        return "overview · \(reachable)/\(n) reachable · poll \(minInterval)s"
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No servers configured")
                .font(.headline)
            Text("Open Settings to add a server by SSH hostname.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings", action: openSettings)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
