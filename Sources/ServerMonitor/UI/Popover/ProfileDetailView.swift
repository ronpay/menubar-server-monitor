import SwiftUI

struct ProfileDetailView: View {
    let profile: Profile
    let snapshot: MetricsSnapshot?
    var history: MetricsHistory?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let snapshot, snapshot.reachable {
                CPUCard(stats: snapshot.cpu, history: history)
                MemoryCard(stats: snapshot.memory, history: history)
                if snapshot.gpus.isEmpty {
                    Text("No NVIDIA GPU detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(snapshot.gpus) { gpu in
                        GPUCard(gpu: gpu, history: history)
                    }
                }
            } else if let snapshot {
                unreachable(error: snapshot.lastError)
            } else {
                ProgressView("Connecting to \(profile.sshHost)…")
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
    }

    private func unreachable(error: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Unreachable", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.warn)
                .font(.headline)
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
