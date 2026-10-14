import Foundation

enum ProcessExecutor {
    static func run(_ executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardInput = nil
        process.standardOutput = stdout
        process.standardError = stderr
        async let outputData = read(stdout.fileHandleForReading)
        async let errorData = read(stderr.fileHandleForReading)
        async let processExit = runUntilTermination(process, stdout: stdout, stderr: stderr)
        let (termination, output, error) = try await (processExit, outputData, errorData)
        guard termination.reason == .exit, termination.status == 0 else {
            let detail = String(decoding: error.isEmpty ? output : error, as: UTF8.self)
            throw PackagingError.process(detail.isEmpty ? "\(executable) 退出码：\(termination.status)" : detail)
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

    private static func read(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
    }
}
