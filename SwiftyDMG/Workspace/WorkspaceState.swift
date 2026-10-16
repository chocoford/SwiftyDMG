import Foundation

/// Durable settings only. Build progress and logs belong to the open window.
struct WorkspaceState: Codable, Equatable, Sendable {
    var sourceURL: URL?
    var outputURL: URL?
    var usesAutomaticOutputName = true
    var options = PackagingOptions()
}
