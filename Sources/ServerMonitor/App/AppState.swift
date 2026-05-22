import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    private static let profilesKey = "ServerMonitor.profiles.v1"
    private static let activeIDKey = "ServerMonitor.activeProfileID.v1"

    var profiles: [Profile] = [] {
        didSet { persistProfiles() }
    }
    var activeProfileID: UUID? {
        didSet {
            UserDefaults.standard.set(activeProfileID?.uuidString, forKey: Self.activeIDKey)
        }
    }
    var snapshots: [UUID: MetricsSnapshot] = [:]
    var history: [UUID: MetricsHistory] = [:]

    private var pollTasks: [UUID: Task<Void, Never>] = [:]
    private var lastCPUSamples: [UUID: CPUSample] = [:]

    init() {
        loadProfiles()
        if let raw = UserDefaults.standard.string(forKey: Self.activeIDKey),
           let uuid = UUID(uuidString: raw),
           profiles.contains(where: { $0.id == uuid }) {
            activeProfileID = uuid
        } else {
            // Default to Overview (nil) when profiles exist; empty state otherwise.
            activeProfileID = nil
        }
    }

    var activeProfile: Profile? {
        guard let id = activeProfileID else { return nil }
        return profiles.first { $0.id == id }
    }

    // MARK: - Mutations

    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        startPolling(profile.id)
    }

    func updateProfile(_ profile: Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let oldInterval = profiles[idx].pollIntervalSec
        let oldHost = profiles[idx].sshHost
        profiles[idx] = profile
        // If transport-relevant fields changed, restart the poller.
        if oldInterval != profile.pollIntervalSec || oldHost != profile.sshHost {
            startPolling(profile.id)
        }
    }

    func removeProfile(id: UUID) {
        pollTasks[id]?.cancel()
        pollTasks.removeValue(forKey: id)
        lastCPUSamples.removeValue(forKey: id)
        snapshots.removeValue(forKey: id)
        history.removeValue(forKey: id)
        profiles.removeAll { $0.id == id }
        if activeProfileID == id {
            activeProfileID = nil // back to Overview
        }
    }

    // MARK: - Polling

    func startAllPollers() {
        for p in profiles { startPolling(p.id) }
    }

    func stopAllPollers() {
        for (_, t) in pollTasks { t.cancel() }
        pollTasks.removeAll()
    }

    func startPolling(_ id: UUID) {
        pollTasks[id]?.cancel()
        pollTasks[id] = Task { [weak self] in
            await self?.pollLoop(id: id)
        }
    }

    private func pollLoop(id: UUID) async {
        while !Task.isCancelled {
            guard let profile = profiles.first(where: { $0.id == id }) else { return }
            let prev = lastCPUSamples[id]
            let result = await MetricsCollector.collect(host: profile.sshHost, previousCPU: prev)
            if Task.isCancelled { return }
            snapshots[id] = result.snapshot
            var h = history[id] ?? MetricsHistory(windowSec: 300)
            h.append(result.snapshot, pollIntervalSec: profile.pollIntervalSec)
            history[id] = h
            if let sample = result.cpuSample { lastCPUSamples[id] = sample }
            let interval = UInt64(max(1, profile.pollIntervalSec)) * 1_000_000_000
            try? await Task.sleep(nanoseconds: interval)
        }
    }

    // MARK: - Persistence

    private func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: Self.profilesKey),
              let decoded = try? JSONDecoder().decode([Profile].self, from: data) else {
            profiles = []
            return
        }
        profiles = decoded
    }

    private func persistProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: Self.profilesKey)
    }
}
