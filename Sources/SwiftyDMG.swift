// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import Foundation
import ArgumentParser

import AppDMG

struct CreateDMGError: LocalizedError {
    var errorDescription: String?
    
    init(message errorDescription: String? = nil) {
        self.errorDescription = errorDescription
    }
}

@main
struct CreateDMG: AsyncParsableCommand {
    @Argument(help: "The url of your app.")
    var appURL: String
    
    @Flag(help: "Print progress updates when creating dmg.")
    var verbose: Bool = false
    
    var progress: String = ""

    mutating func run() async throws {
        guard let url = URL(string: "file://\(appURL)") else { throw CreateDMGError(message: "Invalid url") }
        try await withThrowingTaskGroup(of: Void.self) { [verbose] taskGroup in
            taskGroup.addTask {
                let url = try await AppDMG.default.createDMG(url: url) { progress in
                    if verbose {
                        print("\r", terminator: "")
                        print(progress.description)
                    }
                }
                print("\r", terminator: "")
                print("create-dmg success🎉: \(url.path)")
            }
            
            taskGroup.addTask {
                let animationCharacters = ["-", "\\", "|", "/"]
                let animationInterval = 0.1
                let animationCycles = 100
                
                for _ in 0..<animationCycles {
                    for character in animationCharacters {
                        print("\rcreate-dmg \(character)", terminator: "")
                        fflush(stdout) // 刷新输出，以立即显示字符
                        try await Task.sleep(nanoseconds: UInt64(Int(1e+9 * animationInterval)))
                    }
                }
                print("\r", terminator: "") // 清除最后的动画字符
            }
            
            try await taskGroup.next()
            taskGroup.cancelAll()
        }
   
    }
}
