import Foundation

/// Pure functions that turn raw remote output into typed metrics. Tolerant of
/// missing sections (e.g. servers without nvidia-smi).
enum MetricsParser {
    /// The combined shell snippet we ship to the remote host. Three sections
    /// delimited by recognizable markers so a single ssh call gives us
    /// everything we need. Wrapped in `sh -c` so the bash-style `if/then/fi`
    /// runs even when the remote login shell is fish/csh/etc.
    static let remoteCommand: String = {
        let script = """
        echo '===CPU==='
        head -n1 /proc/stat
        echo '===MEM==='
        grep -E '^(MemTotal|MemAvailable|MemFree):' /proc/meminfo
        echo '===GPU==='
        if command -v nvidia-smi >/dev/null 2>&1; then
          nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null
        fi
        """
        let escaped = script.replacingOccurrences(of: "'", with: "'\\''")
        return "sh -c '\(escaped)'"
    }()

    struct Parsed: Sendable {
        var cpuSample: CPUSample?
        var memory: MemoryStats?
        var gpus: [GPUStats]
    }

    static func parse(_ stdout: String) -> Parsed {
        let sections = split(stdout)
        return Parsed(
            cpuSample: sections["CPU"].flatMap(parseCPUSample),
            memory: sections["MEM"].flatMap(parseMemory),
            gpus: sections["GPU"].map(parseGPUs) ?? []
        )
    }

    // MARK: - Section splitting

    private static func split(_ text: String) -> [String: String] {
        var out: [String: String] = [:]
        var current: String? = nil
        var buffer: [String] = []
        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("===") && line.hasSuffix("===") && line.count >= 6 {
                if let c = current { out[c] = buffer.joined(separator: "\n") }
                let inner = String(line.dropFirst(3).dropLast(3))
                current = inner
                buffer = []
            } else {
                buffer.append(line)
            }
        }
        if let c = current { out[c] = buffer.joined(separator: "\n") }
        return out
    }

    // MARK: - /proc/stat

    /// Parses the first line of /proc/stat: `cpu user nice system idle iowait irq softirq steal guest guest_nice`.
    /// We track `total` and `idle` (idle + iowait); a single sample isn't a
    /// percentage — the caller diffs against the previous sample.
    static func parseCPUSample(_ section: String) -> CPUSample? {
        guard let line = section
            .components(separatedBy: .newlines)
            .first(where: { $0.hasPrefix("cpu ") || $0.hasPrefix("cpu\t") })
        else { return nil }
        let fields = line.split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count >= 5, fields[0] == "cpu" else { return nil }
        let values = fields.dropFirst().compactMap { UInt64($0) }
        guard values.count >= 4 else { return nil }
        let idle = values[3] + (values.count > 4 ? values[4] : 0) // idle + iowait
        let total = values.reduce(0, &+)
        return CPUSample(total: total, idle: idle)
    }

    // MARK: - /proc/meminfo

    static func parseMemory(_ section: String) -> MemoryStats? {
        var total: UInt64? = nil
        var available: UInt64? = nil
        var free: UInt64? = nil
        for line in section.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let value = parts[1]
                .replacingOccurrences(of: "kB", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard let kb = UInt64(value) else { continue }
            switch parts[0] {
            case "MemTotal": total = kb
            case "MemAvailable": available = kb
            case "MemFree": free = kb
            default: break
            }
        }
        guard let total else { return nil }
        let avail = available ?? free ?? 0
        let used = total > avail ? total - avail : 0
        return MemoryStats(usedKB: used, totalKB: total)
    }

    // MARK: - nvidia-smi CSV

    static func parseGPUs(_ section: String) -> [GPUStats] {
        var out: [GPUStats] = []
        for raw in section.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let cols = line.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count >= 6 else { continue }
            guard let index = Int(cols[0]) else { continue }
            let name = cols[1]
            let util = Double(cols[2]) ?? 0
            let memUsed = Int(cols[3]) ?? 0
            let memTotal = Int(cols[4]) ?? 0
            let temp = Double(cols[5]) ?? 0
            let power: Double? = cols.count > 6 ? Double(cols[6]) : nil
            out.append(GPUStats(
                index: index,
                name: name,
                utilizationPct: util,
                memUsedMB: memUsed,
                memTotalMB: memTotal,
                temperatureC: temp,
                powerW: power
            ))
        }
        return out.sorted { $0.index < $1.index }
    }
}
