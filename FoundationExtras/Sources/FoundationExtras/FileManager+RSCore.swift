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
