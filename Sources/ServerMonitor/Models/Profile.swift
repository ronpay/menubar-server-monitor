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
        pollIntervalSec: Int = 5,
        iconSymbol: String = "server.rack",
        menuBarMetric: MenuBarMetric = .gpu
    ) {
        self.id = id
        self.name = name
        self.sshHost = sshHost
        self.pollIntervalSec = max(1, pollIntervalSec)
        self.iconSymbol = iconSymbol
        self.menuBarMetric = menuBarMetric
    }
}
