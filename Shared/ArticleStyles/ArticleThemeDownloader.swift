//
//  ArticleThemeDownloader.swift
//  ArticleThemeDownloader
//
//  Created by Stuart Breckenridge on 20/09/2021.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import Foundation
import Zip

public final class ArticleThemeDownloader: Sendable {
	public static let shared = ArticleThemeDownloader()

	public enum ArticleThemeDownloaderError: LocalizedError {
		case noThemeFile

		public var errorDescription: String? {
			switch self {
			case .noThemeFile:
				return "There is no NetNewsWire theme available."
			}
		}
	}

	private init() {}

	public func handleFile(at location: URL) throws {
		createDownloadDirectoryIfRequired()
		let movedFileLocation = try moveTheme(from: location)
		let unzippedFileLocation = try unzipFile(at: movedFileLocation)
		NotificationCenter.default.post(name: .didEndDownloadingTheme, object: nil, userInfo: ["url" : unzippedFileLocation])
	}


	/// Creates `Application Support/NetNewsWire/Downloads` if needed.
	private func createDownloadDirectoryIfRequired() {
		try? FileManager.default.createDirectory(at: downloadDirectory(), withIntermediateDirectories: true, attributes: nil)
	}

	/// Moves the downloaded `.tmp` file to the `downloadDirectory` and renames it a `.zip`
	/// - Parameter location: The temporary file location.
	/// - Returns: Destination `URL`.
	private func moveTheme(from location: URL) throws -> URL {
		var tmpFileName = location.lastPathComponent
		tmpFileName = tmpFileName.replacingOccurrences(of: ".tmp", with: ".zip")
		let fileUrl = downloadDirectory().appendingPathComponent("\(tmpFileName)")
		try FileManager.default.moveItem(at: location, to: fileUrl)
		return fileUrl
	}

	/// Unzips the zip file
	/// - Parameter location: Location of the zip archive.
	/// - Returns: Enclosed `.nnwtheme` file.
	private func unzipFile(at location: URL) throws -> URL {
		do {
			let unzipDirectory = URL(fileURLWithPath: location.path.replacingOccurrences(of: ".zip", with: ""))
			try Zip.unzipFile(location, destination: unzipDirectory, overwrite: true, password: nil, progress: nil, fileOutputHandler: nil) // Unzips to folder in Application Support/NetNewsWire/Downloads
			try FileManager.default.removeItem(at: location) // Delete zip in Cache
			let themeFilePath = findThemeFile(in: unzipDirectory.path)
			if themeFilePath == nil {
				throw ArticleThemeDownloaderError.noThemeFile
			}
			return URL(fileURLWithPath: unzipDirectory.appendingPathComponent(themeFilePath!).path)
		} catch {
			try? FileManager.default.removeItem(at: location)
			throw error
		}
	}

	/// Performs a deep search of the unzipped directory to find the theme file.
	/// - Parameter searchPath: directory to search
	/// - Returns: optional `String`
	private func findThemeFile(in searchPath: String) -> String? {
		if let directoryContents = FileManager.default.enumerator(atPath: searchPath) {
			while let file = directoryContents.nextObject() as? String {
				if file.hasPrefix("__MACOSX/") {
					//logger.debug("Ignoring theme file in __MACOSX folder.")
					continue
				}
				if file.hasSuffix(".nnwtheme") {
					return file
				}
			}
		}

		return nil
	}

	/// The download directory used by the theme downloader: `Application Support/NetNewsWire/Downloads`
	/// - Returns: `URL`
	private func downloadDirectory() -> URL {
		FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("NetNewsWire/Downloads", isDirectory: true)
	}

	/// Removes downloaded themes, where themes == folders, from `Application Support/NetNewsWire/Downloads`.
	public func cleanUp() {
		guard let filenames = try? FileManager.default.contentsOfDirectory(atPath: downloadDirectory().path) else {
			return
		}
		for path in filenames {
			do {
				if FileManager.default.isFolder(atPath: downloadDirectory().appendingPathComponent(path).path) {
					try FileManager.default.removeItem(atPath: downloadDirectory().appendingPathComponent(path).path)
				}
			} catch {
				print(error)
			}
		}
	}
}
