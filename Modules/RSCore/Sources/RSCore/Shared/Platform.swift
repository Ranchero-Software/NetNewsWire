//
//  Platform.swift
//  RSCore
//
//  Created by Nate Weaver on 2020-01-02.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os

public enum Platform {

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Platform")

	/// Returns true if the app is currently running unit tests.
	public static var isRunningUnitTests: Bool {
		return _isRunningUnitTests
	}

	private static let _isRunningUnitTests: Bool = {

		func checkIfRunningUnitTests() -> Bool {
			// Check multiple indicators to be super-reliable
			let environment = ProcessInfo.processInfo.environment

			// XCTest sets this environment variable
			if environment["XCTestConfigurationFilePath"] != nil {
				return true
			}

			// Check if XCTest framework is loaded
			if NSClassFromString("XCTestCase") != nil {
				return true
			}

			// Check command line arguments for test-related flags
			let arguments = ProcessInfo.processInfo.arguments
			if arguments.contains("-XCTest") || arguments.contains("test") {
				return true
			}

			return false
		}

		if checkIfRunningUnitTests() {
			Self.logger.info("RUNNING UNIT TESTS")
			return true
		}

		Self.logger.info("Not running unit tests")
		return false
	}()

	/// Get the path to a subfolder of the application's data folder (often `Application Support`).
	/// - Parameters:
	///   - appName: The name of the application.
	///   - folderName: The name of the subfolder in the application's data folder.
	public static func dataSubfolder(forApplication appName: String?, folderName: String) -> String? {
		guard let dataFolder = dataFile(forApplication: appName, filename: folderName) else {
			return nil
		}

		do {
			try FileManager.default.createDirectory(at: dataFolder, withIntermediateDirectories: true, attributes: nil)
			return dataFolder.path
		} catch {
			Self.logger.error("Platform.dataSubfolder error: \(error.localizedDescription)")
		}

		return nil
	}
}

private extension Platform {

	static func dataFolder(forApplication appName: String?) -> URL? {
		do {
			var dataFolder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

			if let appName = appName ?? Bundle.main.infoDictionary?["CFBundleExecutable"] as? String {

				dataFolder = dataFolder.appendingPathComponent(appName)

				try FileManager.default.createDirectory(at: dataFolder, withIntermediateDirectories: true, attributes: nil)
			}

			return dataFolder
		} catch {
			Self.logger.error("Platform.dataFolder error: \(error.localizedDescription)")
		}

		return nil
	}

	static func dataFile(forApplication appName: String?, filename: String) -> URL? {
		let dataFolder = self.dataFolder(forApplication: appName)
		return dataFolder?.appendingPathComponent(filename)
	}
}
