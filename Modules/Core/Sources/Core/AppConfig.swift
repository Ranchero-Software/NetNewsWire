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
			createFolderIfNecessary(folderURL)
		}

		return folderURL
	}()

	/// Returns URL to subfolder in cache folder (creating the folder if it doesn’t exist)
	public static func cacheSubfolder(named name: String) -> URL {
		ensureSubfolder(named: name, folderURL: cacheFolder)
	}

	public static let dataFolder: URL = {

#if os(macOS)
		var dataFolder = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		dataFolder = dataFolder.appendingPathComponent(appName)
#elseif os(iOS)
		var dataFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
#endif

		createFolderIfNecessary(dataFolder)
		return dataFolder
	}()

	/// Returns URL to subfolder in data folder (creating the folder if it doesn’t exist)
	public static func dataSubfolder(named name: String) -> URL {
		ensureSubfolder(named: name, folderURL: dataFolder)
	}

	public static func ensureSubfolder(named name: String, folderURL: URL) -> URL {

		let folder = folderURL.appendingPathComponent(name, isDirectory: true)
		createFolderIfNecessary(folder)
		return folder
	}
}

private extension AppConfig {

	static func createFolderIfNecessary(_ folderURL: URL) {
		try! FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
	}
}
