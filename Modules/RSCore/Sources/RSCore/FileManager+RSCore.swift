//
//  FileManager+RSCore.swift
//  RSCore
//
//  Created by Nate Weaver on 2020-01-02.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension FileManager {


	/// Returns whether a path refers to a folder.
	///
	/// - Parameter path: The file path to check.
	///
	/// - Returns: `true` if the path refers to a folder; otherwise `false`.

	func isFolder(atPath path: String) -> Bool {
		let url = URL(fileURLWithPath: path)

		if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) {
			return values.isDirectory ?? false
		}

		return false
	}

	/// Copies files from one folder to another, overwriting any existing files with the same name.
	///
	/// - Parameters:
	/// 	- source: The path of the folder from which to copy files.
	/// 	- destination: The path to the folder at which to place the copied files.
	///
	/// - Note: This function does not copy files whose names begin with a period.
	func copyFiles(fromFolder source: String, toFolder destination: String) throws {
		assert(isFolder(atPath: source))
		assert(isFolder(atPath: destination))

		let sourceURL = URL(fileURLWithPath: source)
		let destinationURL = URL(fileURLWithPath: destination)

		let filenames = try self.contentsOfDirectory(atPath: source)

		for oneFilename in filenames {
			if oneFilename.hasPrefix(".") {
				continue
			}

			let sourceFile = sourceURL.appendingPathComponent(oneFilename)
			let destinationFile = destinationURL.appendingPathComponent(oneFilename)

			try copyFile(atPath: sourceFile.path, toPath: destinationFile.path, overwriting: true)
		}

	}

	/// Retrieve the names of files contained in a folder.
	///
	/// - Parameter folder: The path to the folder whose contents to retrieve.
	///
	/// - Returns: An array containing the names of files in `folder`, an empty
	///   array if `folder` does not refer to a folder, or `nil` if an error occurs.
	func filenames(inFolder folder: String) -> [String]? {
		assert(isFolder(atPath: folder))

		guard isFolder(atPath: folder) else {
			return []
		}

		return try? self.contentsOfDirectory(atPath: folder)
	}

	/// Retrieve the full paths of files contained in a folder.
	///
	/// - Parameter folder: The path to the folder whose contents to retrieve.
	///
	/// - Returns: An array containing the full paths of files in `folder`,
	///   an empty array if `folder` does not refer to a folder, or `nil` if an error occurs.
	func filePaths(inFolder folder: String) -> [String]? {
		guard let filenames = self.filenames(inFolder: folder) else {
			return nil
		}
		
		let url = URL(fileURLWithPath: folder)
		return filenames.map { url.appendingPathComponent($0).path }
	}

}

private extension FileManager {

	/// Copies a single file, possibly overwriting any existing file.
	///
	/// - Parameters:
	///   - source: The source path.
	///   - destination: The destination path.
	///   - overwriting: `true` if an existing file at `destination` should be overwritten.
	func copyFile(atPath source: String, toPath destination: String, overwriting: Bool) throws {
		assert(fileExists(atPath: source))

		if fileExists(atPath: destination) {
			if (overwriting) {
				try removeItem(atPath: destination)
			}
		}

		try copyItem(atPath: source, toPath: destination)
	}

}
