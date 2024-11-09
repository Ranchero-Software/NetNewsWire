//
//  ODB.swift
//  RSDatabase
//
//  Created by Brent Simmons on 4/20/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSDatabaseObjC

// This is not thread-safe. Neither are the other ODB* objects and structs.
// It’s up to the caller to implement thread safety.

public final class ODB: Hashable {

	public let filepath: String

	public var isClosed: Bool {
		return _closed
	}

	static let rootTableID = -1
	public lazy var rootTable: ODBTable? = {
		ODBTable(uniqueID: ODB.rootTableID, name: ODBPath.rootTableName, parentTable: nil, isRootTable: true, odb: self)
	}()

	private var _closed = false
	private let queue: RSDatabaseQueue
	private var odbTablesTable: ODBTablesTable? = ODBTablesTable()
	private var odbValuesTable: ODBValuesTable? = ODBValuesTable()

	public init(filepath: String) {
		self.filepath = filepath
		let queue = RSDatabaseQueue(filepath: filepath, excludeFromBackup: false)
		queue.createTables(usingStatementsSync: ODB.tableCreationStatements)
		self.queue = queue
	}

	/// Call when finished, to make sure no stray references can do undefined things.
	/// It’s not necessary to call this on app termination.
	public func close() {
		guard !_closed else {
			return
		}
		_closed = true
		queue.close()
		odbValuesTable = nil
		odbTablesTable = nil
		rootTable?.close()
		rootTable = nil
	}

	/// Get a reference to an ODBTable at a path, making sure it exists.
	/// Returns nil if there’s a value in the path preventing the table from being made.
	public func ensureTable(_ path: ODBPath) -> ODBTable? {
		return path.ensureTable(with: self)
	}

	/// Compact the database on disk.
	public func vacuum() {
		queue.vacuum()
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(filepath)
	}

	// MARK: - Equatable

	public static func ==(lhs: ODB, rhs: ODB) -> Bool {
		return lhs.filepath == rhs.filepath
	}
}

extension ODB {

	func delete(_ object: ODBObject) -> Bool {
		guard let odbValuesTable = odbValuesTable, let odbTablesTable = odbTablesTable else {
			return false
		}

		if let valueObject = object as? ODBValueObject {
			let uniqueID = valueObject.uniqueID
			queue.updateSync { (database) in
				odbValuesTable.deleteObject(uniqueID: uniqueID, database: database)
			}
		}
		else if let tableObject = object as? ODBTable {
			let uniqueID = tableObject.uniqueID
			queue.updateSync { (database) in
				odbTablesTable.deleteTable(uniqueID: uniqueID, database: database)
			}
		}
		return true
	}

	func deleteChildren(of table: ODBTable) -> Bool {
		guard let odbValuesTable = odbValuesTable, let odbTablesTable = odbTablesTable else {
			return false
		}

		let parentUniqueID = table.uniqueID
		queue.updateSync { (database) in
			odbTablesTable.deleteChildTables(parentUniqueID: parentUniqueID, database: database)
			odbValuesTable.deleteChildObjects(parentUniqueID: parentUniqueID, database: database)
		}
		return true
	}

	func insertTable(name: String, parent: ODBTable) -> ODBTable? {
		guard let odbTablesTable = odbTablesTable else {
			return nil
		}

		var table: ODBTable? = nil
		queue.fetchSync { (database) in
			table = odbTablesTable.insertTable(name: name, parentTable: parent, odb: self, database: database)
		}
		return table!
	}

	func insertValueObject(name: String, value: ODBValue, parent: ODBTable) -> ODBValueObject? {
		guard let odbValuesTable = odbValuesTable else {
			return nil
		}

		var valueObject: ODBValueObject? = nil
		queue.updateSync { (database) in
			valueObject = odbValuesTable.insertValueObject(name: name, value: value, parentTable: parent, database: database)
		}
		return valueObject!
	}

	func fetchChildren(of table: ODBTable) -> ODBDictionary {
		guard let odbValuesTable = odbValuesTable, let odbTablesTable = odbTablesTable else {
			return ODBDictionary()
		}

		var children = ODBDictionary()

		queue.fetchSync { (database) in

			let tables = odbTablesTable.fetchSubtables(of: table, database: database, odb: self)
			let valueObjects = odbValuesTable.fetchValueObjects(of: table, database: database)

			// Keys are lower-cased, since we case-insensitive lookups.

			for valueObject in valueObjects {
				children[valueObject.name] = valueObject
			}

			for table in tables {
				children[table.name] = table
			}
		}

		return children
	}
}

private extension ODB {

	static let tableCreationStatements = """
	CREATE TABLE if not EXISTS odb_tables (id INTEGER PRIMARY KEY AUTOINCREMENT, parent_id INTEGER NOT NULL, name TEXT NOT NULL);

	CREATE TABLE if not EXISTS odb_values (id INTEGER PRIMARY KEY AUTOINCREMENT, odb_table_id INTEGER NOT NULL, name TEXT NOT NULL, primitive_type INTEGER NOT NULL, application_type TEXT, value BLOB);

	CREATE INDEX if not EXISTS odb_tables_parent_id_index on odb_tables (parent_id);
	CREATE INDEX if not EXISTS odb_values_odb_table_id_index on odb_values (odb_table_id);

	CREATE TRIGGER if not EXISTS odb_tables_after_delete_trigger_delete_subtables after delete on odb_tables begin delete from odb_tables where parent_id = OLD.id; end;
	CREATE TRIGGER if not EXISTS odb_tables_after_delete_trigger_delete_child_values after delete on odb_tables begin delete from odb_values where odb_table_id = OLD.id; end;
	"""
}


