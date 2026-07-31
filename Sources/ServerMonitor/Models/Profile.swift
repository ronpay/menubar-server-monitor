import Foundation

enum MenuBarMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case gpu, cpu, memory
    var id: String { rawValue }
    var label: String {
        switch self {
        case .gpu: return "GPU"
        case .cpu: return "CPU"
        case .memory: return "MEM"
        }
    }
}

struct Profile: Codable, Identifiable, Hashable, Sendable {
    static let defaultPollIntervalSec = 30
    static let minPollIntervalSec = 1
    static let maxPollIntervalSec = 3600
    /// The default this app originally shipped with. Profiles still sitting on
    /// it have never been tuned by hand, so they get migrated to the current
    /// default; see `AppState.migrateDefaultPollInterval`.
    static let legacyDefaultPollIntervalSec = 5

    var id: UUID
    var name: String
    var sshHost: String
    var pollIntervalSec: Int
    var iconSymbol: String
    var menuBarMetric: MenuBarMetric

    init(
        id: UUID = UUID(),
        name: String,
        sshHost: String,
        pollIntervalSec: Int = Profile.defaultPollIntervalSec,
        iconSymbol: String = "server.rack",
        menuBarMetric: MenuBarMetric = .gpu
    ) {
        self.id = id
        self.name = name
        self.sshHost = sshHost
        self.pollIntervalSec = Profile.clampPollInterval(pollIntervalSec)
        self.iconSymbol = iconSymbol
        self.menuBarMetric = menuBarMetric
    }

    static func clampPollInterval(_ value: Int) -> Int {
        min(max(value, minPollIntervalSec), maxPollIntervalSec)
    }
}
