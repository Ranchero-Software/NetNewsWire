//
//  ODBTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 4/21/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public final class ODBTable: ODBObject, Hashable {

	let uniqueID: Int
	public let isRootTable: Bool
	public let odb: ODB
	public let parentTable: ODBTable?
	public let name: String
	public let path: ODBPath
	private var _children: ODBDictionary?

	public var children: ODBDictionary {
		get {
			if _children == nil {
				_children = odb.fetchChildren(of: self)
			}
			return _children!
		}
		set {
			_children = newValue
		}
	}

	public lazy var rawValueTable = {
		return ODBRawValueTable(table: self)
	}()

	init(uniqueID: Int, name: String, parentTable: ODBTable?, isRootTable: Bool, odb: ODB) {
		self.uniqueID = uniqueID
		self.name = name
		self.parentTable = parentTable
		self.isRootTable = isRootTable
		self.path = isRootTable ? ODBPath.root : parentTable!.path + name
		self.odb = odb
	}

	/// Get the ODBObject for the given name.
	public subscript(_ name: String) -> ODBObject? {
		return children[name]
	}

	/// Fetch the ODBValue for the given name.
	public func odbValue(_ name: String) -> ODBValue? {
		return (self[name] as? ODBValueObject)?.value
	}

	/// Set the ODBValue for the given name.
	public func set(_ odbValue: ODBValue, name: String) -> Bool {
		// Don’t bother if key/value pair already exists.
		// If child with same name exists, delete it.

		let existingObject = self[name]
		if let existingValue = existingObject as? ODBValueObject, existingValue.value == odbValue {
			return true
		}

		guard let valueObject = odb.insertValueObject(name: name, value: odbValue, parent: self) else {
			return false
		}
		if let existingObject = existingObject {
			delete(existingObject)
		}
		addChild(name: name, object: valueObject)
		return true
	}

	/// Fetch the raw value for the given name.
	public func rawValue(_ name: String) -> Any? {
		return (self[name] as? ODBValueObject)?.value.rawValue
	}

	/// Create a value object and set it for the given name.
	@discardableResult
	public func set(_ rawValue: Any, name: String) -> Bool {
		guard let odbValue = ODBValue(rawValue: rawValue) else {
			return false
		}
		return set(odbValue, name: name)
	}

	/// Delete all children — empty the table.
	public func deleteChildren() -> Bool {
		guard odb.deleteChildren(of: self) else {
			return false
		}
		_children = ODBDictionary()
		return true
	}

	/// Delete a child object.
	@discardableResult
	public func delete(_ object: ODBObject) -> Bool {
		return odb.delete(object)
	}

	/// Delete a child with the given name.
	@discardableResult
	public func delete(name: String) -> Bool {
		guard let child = self[name] else {
			return false
		}
		return delete(child)
	}

	/// Fetch the subtable with the given name.
	public func subtable(name: String) -> ODBTable? {
		return self[name] as? ODBTable
	}

	/// Add a subtable with the given name. Overwrites previous child with that name.
	public func addSubtable(name: String) -> ODBTable? {
		let existingObject = self[name]
		guard let subTable = odb.insertTable(name: name, parent: self) else {
			return nil
		}
		if let existingObject = existingObject {
			delete(existingObject)
		}
		addChild(name: name, object: subTable)
		return subTable
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(uniqueID)
		hasher.combine(odb)
	}

	// MARK: - Equatable

	public static func ==(lhs: ODBTable, rhs: ODBTable) -> Bool {
		return lhs.uniqueID == rhs.uniqueID && lhs.odb == rhs.odb
	}
}

extension ODBTable {

	func close() {
		// Called from ODB when database is closing.
		if let rawChildren = _children {
			rawChildren.forEach { (key: String, value: ODBObject) in
				if let table = value as? ODBTable {
					table.close()
				}
			}
		}
		_children = nil
	}
}

private extension ODBTable {

	func addChild(name: String, object: ODBObject) {
		children[name] = object
	}

	func ensureChildren() {
		let _ = children
	}
}
