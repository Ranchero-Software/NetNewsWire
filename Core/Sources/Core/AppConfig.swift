//
//  AppConfig.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/26/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

import Foundation

public final class AppConfig {

	public static let appName: String = (Bundle.main.infoDictionary!["CFBundleExecutable"]! as! String)

	public static let cacheFolder: URL = {

		let folderURL: URL

		if let userCacheFolder = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
			folderURL = userCacheFolder
		} else {
			let bundleIdentifier = (Bundle.main.infoDictionary!["CFBundleIdentifier"]! as! String)
			let tempFolder = (NSTemporaryDirectory() as NSString).appendingPathComponent(bundleIdentifier)
			folderURL = URL(fileURLWithPath: tempFolder, isDirectory: true)
			try! FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
		}

		return folderURL
	}()

	/// Returns URL to subfolder in cache folder (creating the folder if it doesn’t exist)
	public static func cacheSubfolder(named name: String) -> URL {
		subfolder(name, in: cacheFolder)
	}

	public static let dataFolder: URL = {

#if os(macOS)
		var dataFolder = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
		dataFolder = dataFolder.appendingPathComponent(appName)

		try! FileManager.default.createDirectory(at: dataFolder, withIntermediateDirectories: true, attributes: nil)
		return dataFolder

#elseif os(iOS)
		FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
#endif
	}()

	/// Returns URL to subfolder in data folder (creating the folder if it doesn’t exist)
	public static func dataSubfolder(named name: String) -> URL {
		subfolder(name, in: dataFolder)
	}

}

private extension AppConfig {

	static func subfolder(_ name: String, in folderURL: URL) -> URL {

		let folder = folderURL.appendingPathComponent(name, isDirectory: true)
		try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
		return folder
	}
}
