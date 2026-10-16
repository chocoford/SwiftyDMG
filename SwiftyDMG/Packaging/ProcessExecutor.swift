import Foundation

enum ProcessExecutor {
    static func run(
        _ executable: String, arguments: [String], onLog: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = nil
        process.standardOutput = stdout
        process.standardError = stderr
        let command = ([executable] + arguments).map {
            "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }.joined(separator: " ")
        onLog?("$ \(command)")
        let started = ProcessInfo.processInfo.systemUptime
        async let outputData = read(stdout.fileHandleForReading, onLog: onLog)
        async let errorData = read(stderr.fileHandleForReading, prefix: "[stderr] ", onLog: onLog)
        async let processExit = runUntilTermination(process, stdout: stdout, stderr: stderr)
        let (termination, output, error) = try await (processExit, outputData, errorData)
        let elapsed = String(format: "%.2f", ProcessInfo.processInfo.systemUptime - started)
        let exit = termination.reason == .exit
            ? "Exited with status \(termination.status)"
            : "Terminated by signal \(termination.status)"
        onLog?("\(exit) (\(elapsed)s)")
        guard termination.reason == .exit, termination.status == 0 else {
            let detail = String(decoding: error.isEmpty ? output : error, as: UTF8.self)
            throw PackagingError.process(detail.isEmpty ? String(localizable: .errorProcessExitStatus(executable, Int(termination.status))) : detail)
        }
        return String(decoding: output, as: UTF8.self)
    }

    private static func runUntilTermination(
        _ process: Process, stdout: Pipe, stderr: Pipe
    ) async throws -> (status: Int32, reason: Process.TerminationReason) {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { task in
                continuation.resume(returning: (task.terminationStatus, task.terminationReason))
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                try? stdout.fileHandleForWriting.close()
                try? stderr.fileHandleForWriting.close()
                continuation.resume(throwing: error)
            }
        }
    }

    private static func read(
        _ handle: FileHandle, prefix: String = "", onLog: (@Sendable (String) -> Void)? = nil
    ) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var output = Data()
                var line = Data()
                while true {
                    let chunk = handle.availableData
                    guard !chunk.isEmpty else { break }
                    output.append(chunk)
                    guard let onLog else { continue }
                    // Preserve split UTF-8 characters and support CR-based progress output.
                    for byte in chunk {
                        if byte == 10 || byte == 13 {
                            if !line.isEmpty {
                                onLog(prefix + String(decoding: line, as: UTF8.self))
                                line.removeAll(keepingCapacity: true)
                            }
                        } else {
                            line.append(byte)
                        }
                    }
                }
                if !line.isEmpty { onLog?(prefix + String(decoding: line, as: UTF8.self)) }
                continuation.resume(returning: output)
            }
        }
    }
}
