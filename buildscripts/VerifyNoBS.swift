#!/usr/bin/swift

// This script is meant to be called from an Xcode run script build phase
// It verifies there are no buildSettings embedded in the Xcode project
// as it is preferable to have build settings specified in .xcconfig files

// How to use:
// Put this script in a folder called 'buildscripts' next to your xcode project
// Then, add a Run script build phase to one of your targets with this as the script
//
//   xcrun -sdk macosx swift buildscripts/VerifyNoBS.swift  --xcode  ${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj/project.pbxproj
//

import Darwin
import Foundation

/// A message with its file name and location
struct LocatedMessage {
    let message: String
    let fileUrl: URL
    let line: Int
}

/// Utility to process the pbxproj file
struct BuildSettingsVerifier {
    
    public enum ProcessXcodeprojResult {
        case foundBuildSettings([LocatedMessage])
        case error(String)
        case success(String)
    }
    
    /// Mode to run the utility in. Mode defines the output format
    public enum Mode {
        /// Write errors to stderr
        case cmd
        /// Write errors to stdout in a format that is picked up by Xcode
        case xcode
    }
    
    /// The mode to run in
    let mode: Mode
    
    /// The absolute file URL to the pbxproj file
    let projUrl: URL
    
    init(mode: Mode, projUrl: URL) {
        self.mode = mode
        self.projUrl = projUrl
    }
    
    /// Reports an error either to stderr or to stdout, depending on the mode
    func reportError(message: String, fileUrl: URL? = nil, line: Int? = nil) {
        switch mode {
        case .cmd:
            let stderr = FileHandle.standardError
            if let data = "\(message)\n".data(using: String.Encoding.utf8, allowLossyConversion: false) {
                stderr.write(data)
            } else {
                print("There was an error.  Could not convert error message to printable string")
            }
        case .xcode:
            var messageParts = [String]()
            
            if let fileUrl = fileUrl {
                messageParts.append("\(fileUrl.path):")
            }
            
            if let line = line {
                messageParts.append("\(line): ")
            }
            
            messageParts.append("error: \(message)")
            
            print(messageParts.joined())
        }
    }

    /// Inspect the pbxproj file for non-empty buildSettings
    func processXcodeprojAt(url: URL) -> ProcessXcodeprojResult {
        let startTime = Date()
        guard let xcodeproj = try? String(contentsOf: url, encoding: String.Encoding.utf8) else {
            return .error("Failed to read xcodeproj contents from \(url)")
        }
        let lines = xcodeproj.components(separatedBy: CharacterSet.newlines)
        print("Found \(lines.count) lines")

        var locatedMessages: [LocatedMessage] = []
        var inBuildSettingsBlock = false
        for (lineIndex, nthLine) in lines.enumerated() {
            if inBuildSettingsBlock {
                if nthLine.range(of: "\\u007d[:space:]*;", options: .regularExpression) != nil {
                    inBuildSettingsBlock = false
                } else if nthLine.range(of: "CODE_SIGN_IDENTITY") != nil {

                } else {
                    let message = mode == .cmd ? "    \(nthLine)\n" : "Setting '\(nthLine.trimmingCharacters(in: .whitespacesAndNewlines))' should be in an xcconfig file"
                    locatedMessages.append(LocatedMessage(
                        message: message,
                        fileUrl: url,
                        line: lineIndex + 1
                    ))
                }
            } else {
                if nthLine.range(of: "buildSettings[:space:]*=", options: .regularExpression) != nil {
                    inBuildSettingsBlock = true
                }
            }
        }

        let timeInterval = Date().timeIntervalSince(startTime)
        print("Process took \(timeInterval) seconds")
        if locatedMessages.count > 0 {
            return .foundBuildSettings(locatedMessages)
        }
        return .success(":-)")
    }
    
    public func verify() -> Int32 {
        print("Verifying there are no build settings...")
        
        let result = processXcodeprojAt(url: projUrl)

        switch result {
        case .error(let str):
            reportError(message: "Error verifying build settings: \(str)")
            return EXIT_FAILURE
        case .foundBuildSettings(let locatedMessages):
            reportError(message: "Found build settings in project file")
            for msg in locatedMessages {
                reportError(message: msg.message, fileUrl: msg.fileUrl, line: msg.line)
            }
            return EXIT_FAILURE
        case .success:
            print("No build settings found in project file")
            return EXIT_SUCCESS
        }
    }
}

var commandLineArgs = CommandLine.arguments.dropFirst()
//print("processArgs were \(commandLineArgs)")

if commandLineArgs.count < 1 {
    print("Usage: \(#file) [--xcode] /path/to/Project.xcodeproj/project.pbxproj")
    exit(EXIT_FAILURE)
} else {
    let xcodeProjFilePath = commandLineArgs.removeLast()
    let mode: BuildSettingsVerifier.Mode = commandLineArgs.count > 0 && commandLineArgs.last == "--xcode" ? .xcode : .cmd
    let myUrl = URL(fileURLWithPath: xcodeProjFilePath)
    let verifier = BuildSettingsVerifier(mode: mode, projUrl: myUrl)
    let exitCode = verifier.verify()

    exit(exitCode)
}
