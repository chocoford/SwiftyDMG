import Foundation

struct BuildLogEntry: Identifiable {
    let id = UUID()
    let elapsed: TimeInterval
    let message: String

    var text: String {
        let milliseconds = max(0, Int(elapsed * 1_000))
        let timestamp = String(format: "%02d:%02d.%03d", milliseconds / 60_000,
                               milliseconds / 1_000 % 60, milliseconds % 1_000)
        return "[\(timestamp)] \(message)"
    }
}

struct BuildLogStep: Identifiable {
    enum Status: Equatable {
        case running, succeeded, failed
    }

    let id = UUID()
    let stage: BuildStage
    let heading: BuildLogEntry
    let startedAt: TimeInterval
    var finishedAt: TimeInterval?
    var status = Status.running
    var entries: [BuildLogEntry] = []

    var text: String {
        ([heading.text] + entries.map(\.text)).joined(separator: "\n")
    }

    func duration(at uptime: TimeInterval) -> TimeInterval {
        max(0, (finishedAt ?? uptime) - startedAt)
    }
}
