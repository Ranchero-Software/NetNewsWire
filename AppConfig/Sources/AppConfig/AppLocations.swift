//
//  AppLocations.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/26/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor public final class AppLocations {

	private static var cacheFolder: URL = {

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

	public static var faviconsFolder: URL = {
		return createSubfolder(named: "Favicons", in: cacheFolder)
	}()

	public static var imagesFolder: URL = {
		return createSubfolder(named: "Images", in: cacheFolder)
	}()
}

private extension AppLocations {

	static func createSubfolder(named subfolderName: String, in folderURL: URL) -> URL {

		let folder = folderURL.appendingPathComponent(subfolderName, isDirectory: true)
		try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
		return folder
	}
}
