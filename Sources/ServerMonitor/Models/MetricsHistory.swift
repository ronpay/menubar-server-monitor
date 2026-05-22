import Foundation

struct MetricsHistory: Sendable {
    var samples: [MetricsSnapshot] = []
    let windowSec: Int

    init(windowSec: Int = 300) {
        self.windowSec = windowSec
    }

    mutating func append(_ snapshot: MetricsSnapshot, pollIntervalSec: Int) {
        samples.append(snapshot)
        let cap = max(2, Int(ceil(Double(windowSec) / Double(max(1, pollIntervalSec)))))
        if samples.count > cap {
            samples.removeFirst(samples.count - cap)
        }
        let cutoff = snapshot.timestamp.addingTimeInterval(-Double(windowSec))
        if let firstFresh = samples.firstIndex(where: { $0.timestamp >= cutoff }), firstFresh > 0 {
            samples.removeFirst(firstFresh)
        }
    }

    /// Reachable samples only, ordered oldest → newest.
    var reachableSamples: [MetricsSnapshot] {
        samples.filter { $0.reachable }
    }
}
