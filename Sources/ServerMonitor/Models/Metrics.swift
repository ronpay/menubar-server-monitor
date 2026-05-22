import Foundation

struct CPUStats: Sendable, Hashable {
    var utilizationPct: Double
}

struct MemoryStats: Sendable, Hashable {
    var usedKB: UInt64
    var totalKB: UInt64

    var usedBytes: UInt64 { usedKB * 1024 }
    var totalBytes: UInt64 { totalKB * 1024 }
    var utilizationPct: Double {
        guard totalKB > 0 else { return 0 }
        return Double(usedKB) / Double(totalKB) * 100
    }
}

struct GPUStats: Sendable, Hashable, Identifiable {
    var index: Int
    var name: String
    var utilizationPct: Double
    var memUsedMB: Int
    var memTotalMB: Int
    var temperatureC: Double
    var powerW: Double?

    var id: Int { index }
    var memUtilizationPct: Double {
        guard memTotalMB > 0 else { return 0 }
        return Double(memUsedMB) / Double(memTotalMB) * 100
    }
}

struct MetricsSnapshot: Sendable, Hashable {
    var timestamp: Date
    var cpu: CPUStats
    var memory: MemoryStats
    var gpus: [GPUStats]
    var reachable: Bool
    var lastError: String?
}

/// Raw counters from /proc/stat sampled at one instant; differenced across two
/// samples to compute CPU utilization.
struct CPUSample: Sendable, Hashable {
    var total: UInt64
    var idle: UInt64

    static func delta(previous: CPUSample, current: CPUSample) -> Double {
        let totalDelta = current.total &- previous.total
        let idleDelta = current.idle &- previous.idle
        guard totalDelta > 0 else { return 0 }
        let busy = Double(totalDelta) - Double(idleDelta)
        return max(0, min(100, busy / Double(totalDelta) * 100))
    }
}
