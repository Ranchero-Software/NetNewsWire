//
//  ODBPath.swift
//  RSDatabase
//
//  Created by Brent Simmons on 4/21/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

/**
	An ODBPath is an array like ["system", "verbs", "apps", "Xcode"].
	The first element in the array may be "root". If so, it’s ignored: "root" is implied.
	An empty array or ["root"] refers to the root table.
	A path does not necessarily point to something that exists. It’s like file paths or URLs.
*/

public struct ODBPath: Hashable {

	/// The last element in the path. May not have same capitalization as canonical name in the database.
	public let name: String

	/// True if this path points to a root table.
	public let isRoot: Bool

	/// Root table name. Constant.
	public static let rootTableName = "root"

	/// Elements of the path minus any unneccessary initial "root" element.
	public let elements: [String]

	/// ODBPath that represents the root table.
	public static let root = ODBPath.path([String]())

	/// The optional path to the parent table. Nil only if path is to the root table.
	public var parentTablePath: ODBPath? {
		if isRoot {
			return nil
		}
		return ODBPath.path(Array(elements.dropLast()))
	}

	private static var pathCache = [[String]: ODBPath]()
	private static let pathCacheLock = NSLock()

	private init(elements: [String]) {

		let canonicalElements = ODBPath.dropLeadingRootElement(from: elements)
		self.elements = canonicalElements

		if canonicalElements.count < 1 {
			self.name = ODBPath.rootTableName
			self.isRoot = true
		}
		else {
			self.name = canonicalElements.last!
			self.isRoot = false
		}
	}

	// MARK: - API

	/// Create a path.
	public static func path(_ elements: [String]) -> ODBPath {

		pathCacheLock.lock()
		defer {
			pathCacheLock.unlock()
		}

		if let cachedPath = pathCache[elements] {
			return cachedPath
		}
		let path = ODBPath(elements: elements)
		pathCache[elements] = path
		return path
	}

	/// Create a path by adding an element.
	public func pathByAdding(_ element: String) -> ODBPath {
		return ODBPath.path(elements + [element])
	}

	/// Create a path by adding an element.
	public static func +(lhs: ODBPath, rhs: String) -> ODBPath {
		return lhs.pathByAdding(rhs)
	}

	/// Fetch the database object at this path.
	public func odbObject(with odb: ODB) -> ODBObject? {
		return resolvedObject(odb)
	}

	/// Fetch the value at this path.
	public func odbValue(with odb: ODB) -> ODBValue? {
		return parentTable(with: odb)?.odbValue(name)
	}

	/// Set a value for this path. Will overwrite existing value or table.
	public func setODBValue(_ value: ODBValue, odb: ODB) -> Bool {
		return parentTable(with: odb)?.set(value, name: name) ?? false
	}

	/// Fetch the raw value at this path.
	public func rawValue(with odb: ODB) -> Any? {
		return parentTable(with: odb)?.rawValue(name)
	}

	/// Set the raw value for this path. Will overwrite existing value or table.
	@discardableResult
	public func setRawValue(_ rawValue: Any, odb: ODB) -> Bool {
		return parentTable(with: odb)?.set(rawValue, name: name) ?? false
	}

	/// Delete value or table at this path.
	public func delete(from odb: ODB) -> Bool {
		return parentTable(with: odb)?.delete(name: name) ?? false
	}

	/// Fetch the table at this path.
	public func table(with odb: ODB) -> ODBTable? {
		return odbObject(with: odb) as? ODBTable
	}

	/// Fetch the parent table. Nil if this is the root table.
	public func parentTable(with odb: ODB) -> ODBTable? {
		return parentTablePath?.table(with: odb)
	}

	/// Creates a table — will delete existing table.
	public func createTable(with odb: ODB) -> ODBTable? {
		return parentTable(with: odb)?.addSubtable(name: name)
	}

	/// Return the table for the final item in the path.
	/// Won’t delete anything.
	@discardableResult
	public func ensureTable(with odb: ODB) -> ODBTable? {

		if isRoot {
			return odb.rootTable
		}

		if let existingObject = odbObject(with: odb) {
			if let existingTable = existingObject as? ODBTable {
				return existingTable
			}
			return nil // It must be a value: don’t overwrite.
		}

		if let parentTable = parentTablePath!.ensureTable(with: odb) {
			return parentTable.addSubtable(name: name)
		}
		return nil
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(elements)
	}

	// MARK: - Equatable

	public static func ==(lhs: ODBPath, rhs: ODBPath) -> Bool {
		return lhs.elements == rhs.elements
	}
}

// MARK: - Private

private extension ODBPath {

	func resolvedObject(_ odb: ODB) -> ODBObject? {
		if isRoot {
			return odb.rootTable
		}
		guard let table = parentTable(with: odb) else {
			return nil
		}
		return table[name]
	}

	static func dropLeadingRootElement(from elements: [String]) -> [String] {
		if elements.count < 1 {
			return elements
		}
		
		let firstElement = elements.first!
		if firstElement == ODBPath.rootTableName {
			return Array(elements.dropFirst())
		}

		return elements
	}
}
