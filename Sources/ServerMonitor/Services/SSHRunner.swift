import Foundation

struct SSHResult: Sendable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

enum SSHError: Error, LocalizedError, Sendable {
    case launchFailed(String)
    case timedOut
    case nonZeroExit(code: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let msg): return "ssh launch failed: \(msg)"
        case .timedOut: return "ssh timed out"
        case .nonZeroExit(let code, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "ssh exit \(code): \(trimmed.isEmpty ? "(no stderr)" : trimmed)"
        }
    }
}

enum SSHRunner {
    /// Runs `command` on `host` (an alias resolvable from ~/.ssh/config).
    /// BatchMode prevents interactive password / passphrase prompts.
    static func run(
        host: String,
        command: String,
        connectTimeoutSec: Int = 5,
        overallTimeoutSec: Int = 15
    ) async -> Result<SSHResult, SSHError> {
        let args = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=\(connectTimeoutSec)",
            "-o", "StrictHostKeyChecking=accept-new",
            host,
            "--",
            command,
        ]
        return await runProcess(executable: "/usr/bin/ssh", args: args, overallTimeoutSec: overallTimeoutSec)
    }

    /// Resolves the effective ssh config for `host` (`ssh -G`). Useful for
    /// validating a hostname before saving a profile.
    static func resolve(host: String) async -> Result<SSHResult, SSHError> {
        await runProcess(
            executable: "/usr/bin/ssh",
            args: ["-G", host],
            overallTimeoutSec: 5
        )
    }

    private static func runProcess(
        executable: String,
        args: [String],
        overallTimeoutSec: Int
    ) async -> Result<SSHResult, SSHError> {
        await withCheckedContinuation { (cont: CheckedContinuation<Result<SSHResult, SSHError>, Never>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            process.standardInput = FileHandle.nullDevice

            let outBox = DataBox()
            let errBox = DataBox()
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { handle.readabilityHandler = nil } else { outBox.append(chunk) }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty { handle.readabilityHandler = nil } else { errBox.append(chunk) }
            }

            let resolved = Atomic(false)
            process.terminationHandler = { proc in
                guard resolved.compareAndSet(expected: false, new: true) else { return }
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                // Drain anything still buffered.
                let tailOut = (try? outPipe.fileHandleForReading.readToEnd()) ?? nil
                let tailErr = (try? errPipe.fileHandleForReading.readToEnd()) ?? nil
                if let tailOut { outBox.append(tailOut) }
                if let tailErr { errBox.append(tailErr) }
                let result = SSHResult(
                    exitCode: proc.terminationStatus,
                    stdout: outBox.string(),
                    stderr: errBox.string()
                )
                cont.resume(returning: .success(result))
            }

            do {
                try process.run()
            } catch {
                if resolved.compareAndSet(expected: false, new: true) {
                    cont.resume(returning: .failure(.launchFailed(error.localizedDescription)))
                }
                return
            }

            // Watchdog: kill the process if it overruns the overall timeout.
            let timeoutNs = UInt64(overallTimeoutSec) * 1_000_000_000
            Task.detached {
                try? await Task.sleep(nanoseconds: timeoutNs)
                if process.isRunning {
                    process.terminate()
                    // give it a moment, then SIGKILL
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                    if resolved.compareAndSet(expected: false, new: true) {
                        cont.resume(returning: .failure(.timedOut))
                    }
                }
            }
        }
    }
}

/// Tiny thread-safe accumulator for pipe data so concurrent readability
/// handlers don't race on a plain `Data`.
private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func append(_ chunk: Data) { lock.lock(); data.append(chunk); lock.unlock() }
    func string() -> String {
        lock.lock(); defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private final class Atomic<T: Equatable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T
    init(_ value: T) { self.value = value }
    func compareAndSet(expected: T, new: T) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard value == expected else { return false }
        value = new
        return true
    }
}
