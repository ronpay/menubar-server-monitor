import Foundation

struct PollResult: Sendable {
    var snapshot: MetricsSnapshot
    /// Carried forward so the next poll can compute a CPU% delta.
    var cpuSample: CPUSample?
}

enum MetricsCollector {
    static func collect(host: String, previousCPU: CPUSample?) async -> PollResult {
        let now = Date()
        let outcome = await SSHRunner.run(host: host, command: MetricsParser.remoteCommand)

        switch outcome {
        case .failure(let err):
            return PollResult(
                snapshot: MetricsSnapshot(
                    timestamp: now,
                    cpu: CPUStats(utilizationPct: 0),
                    memory: MemoryStats(usedKB: 0, totalKB: 0),
                    gpus: [],
                    reachable: false,
                    lastError: err.localizedDescription
                ),
                cpuSample: previousCPU
            )

        case .success(let result):
            if result.exitCode != 0 {
                return PollResult(
                    snapshot: MetricsSnapshot(
                        timestamp: now,
                        cpu: CPUStats(utilizationPct: 0),
                        memory: MemoryStats(usedKB: 0, totalKB: 0),
                        gpus: [],
                        reachable: false,
                        lastError: SSHError.nonZeroExit(code: result.exitCode, stderr: result.stderr).localizedDescription
                    ),
                    cpuSample: previousCPU
                )
            }

            let parsed = MetricsParser.parse(result.stdout)
            let cpuPct: Double = {
                guard let prev = previousCPU, let cur = parsed.cpuSample else { return 0 }
                return CPUSample.delta(previous: prev, current: cur)
            }()

            return PollResult(
                snapshot: MetricsSnapshot(
                    timestamp: now,
                    cpu: CPUStats(utilizationPct: cpuPct),
                    memory: parsed.memory ?? MemoryStats(usedKB: 0, totalKB: 0),
                    gpus: parsed.gpus,
                    reachable: true,
                    lastError: nil
                ),
                cpuSample: parsed.cpuSample ?? previousCPU
            )
        }
    }
}
