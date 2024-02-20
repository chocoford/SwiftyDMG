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
    static var configuration: CommandConfiguration = CommandConfiguration(abstract: "A tool help you create dmg for your app.")

    @Argument(help: "The url of your app.")
    var appURL: String
    
    @Option(name: [.customLong("output"), .customShort("o")], help: "The destination of the dmg.")
    var destination: String?
    
    @Option(name: [.customLong("background"), .customShort("b")], help: "The background image of the dmg.")
    var backgroundURLString: String?
    
    
    @Flag(name: [.customLong("nobackground"), .customLong("nobg")], help: "Remove the background of the dmg.")
    var noBackground: Bool = false
    
    @Flag(name: .customLong("skipcodesign"), help: "Skip codesign for the dmg.")
    var skipCodesign: Bool = false
    
    @Flag(help: "Print progress updates when creating dmg.")
    var verbose: Bool = false
    
    
    private func buildPath(_ urlString: String) -> String {
        let currentPath = FileManager.default.currentDirectoryPath
        let urlString = urlString.hasPrefix("/") ? urlString : currentPath + "/" + urlString
        
        return urlString
    }

    mutating func run() async throws {
        guard let url = URL(string: "file://\(buildPath(appURL))") else { throw CreateDMGError(message: "Invalid url") }
        
        
        let desURL: URL?
        if let destination = destination {
            desURL = URL(string: "file://\(buildPath(destination))")
        } else {
            desURL = nil
        }
        
        let bgURL: AppDMG.DMGBackgroundOption
        if noBackground {
            bgURL = .skip
        } else if let bgURLString = backgroundURLString {
            guard let url = URL(string: "file://\(buildPath(bgURLString))") else {
                throw CreateDMGError(message: "Invalid background image url")
            }
            bgURL = .manually(url)
        } else {
            bgURL = .default
        }
        
        let codesignOption: AppDMG.CodesignOption
        if skipCodesign {
            codesignOption = .skip
        } else {
            codesignOption = .auto
        }
        
        
        try await withThrowingTaskGroup(of: Void.self) { [verbose] taskGroup in
            taskGroup.addTask {
                let url = try await AppDMG.default.createDMG(
                    url: url,
                    to: desURL,
                    backgroundImage: bgURL,
                    codesign: codesignOption
                ) { progress in
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
