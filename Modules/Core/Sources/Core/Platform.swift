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
			os_log(.error, log: .default, "Platform.dataSubfolder error: %@", error.localizedDescription)
		}

		return nil
	}
}

private extension Platform {

	static func dataFolder(forApplication appName: String?) -> URL? {
		do {
			var dataFolder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
			dataFolder = dataFolder.appendingPathComponent(AppConfig.appName)

			try FileManager.default.createDirectory(at: dataFolder, withIntermediateDirectories: true, attributes: nil)

			return dataFolder
		} catch {
			os_log(.error, log: .default, "Platform.dataFolder error: %@", error.localizedDescription)
		}

		return nil
	}

	static func dataFile(forApplication appName: String?, filename: String) -> URL? {
		let dataFolder = self.dataFolder(forApplication: appName)
		return dataFolder?.appendingPathComponent(filename)
	}
}
