//
//  ArticleThemeDownloader.swift
//  ArticleThemeDownloader
//
//  Created by Stuart Breckenridge on 20/09/2021.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation
import Zip

public struct ArticleThemeDownloader {
	
	static func handleFile(at location: URL) throws {
		#if os(iOS)
		createDownloadDirectoryIfRequired()
		#endif
		let movedFileLocation = try moveTheme(from: location)
		let unzippedFileLocation = try unzipFile(at: movedFileLocation)
		let renamedFile = try renameFileToThemeName(at: unzippedFileLocation)
		NotificationCenter.default.post(name: .didEndDownloadingTheme, object: nil, userInfo: ["url" : renamedFile])
	}
	
	private static func createDownloadDirectoryIfRequired() {
		let downloadDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
		try? FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true, attributes: nil)
	}
	
	private static func moveTheme(from location: URL) throws -> URL {
		#if os(iOS)
		var downloadDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
		#else
		var downloadDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		#endif
		let tmpFileName = UUID().uuidString + ".zip"
		downloadDirectory.appendPathComponent("\(tmpFileName)")
		try FileManager.default.moveItem(at: location, to: downloadDirectory)
		return downloadDirectory
	}
	
	private static func unzipFile(at location: URL) throws -> URL {
		var unzippedDir = location.deletingLastPathComponent()
		unzippedDir.appendPathComponent("newtheme.nnwtheme")
		do {
			try Zip.unzipFile(location, destination: unzippedDir, overwrite: true, password: nil, progress: nil, fileOutputHandler: nil)
			try FileManager.default.removeItem(at: location)
			return unzippedDir
		} catch {
			try? FileManager.default.removeItem(at: location)
			throw error
		}
	}
	
	private static func renameFileToThemeName(at location: URL) throws -> URL {
		let decoder = PropertyListDecoder()
		let plistURL = URL(fileURLWithPath: location.appendingPathComponent("Info.plist").path)
		let data = try Data(contentsOf: plistURL)
		let plist = try decoder.decode(ArticleThemePlist.self, from: data)
		var renamedUnzippedDir = location.deletingLastPathComponent()
		renamedUnzippedDir.appendPathComponent(plist.name + ".nnwtheme")
		if FileManager.default.fileExists(atPath: renamedUnzippedDir.path) {
			try FileManager.default.removeItem(at: renamedUnzippedDir)
		}
		try FileManager.default.moveItem(at: location, to: renamedUnzippedDir)
		return renamedUnzippedDir
	}
	
	
	
}
