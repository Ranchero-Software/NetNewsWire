//
//  ODBTablesTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 4/20/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSDatabaseObjC

final class ODBTablesTable: DatabaseTable {

	let name = "odb_tables"

	private struct Key {
		static let uniqueID = "id"
		static let parentID = "parent_id"
		static let name = "name"
	}

	func fetchSubtables(of table: ODBTable, database: FMDatabase, odb: ODB) -> Set<ODBTable> {
		guard let rs: FMResultSet = database.executeQuery("select * from odb_tables where parent_id = ?", withArgumentsIn: [table.uniqueID]) else {
			return Set<ODBTable>()
		}
		return rs.mapToSet{ createTable(with: $0, parentTable: table, odb: odb) }
	}

	func insertTable(name: String, parentTable: ODBTable, odb: ODB, database: FMDatabase) -> ODBTable {
		let d: DatabaseDictionary = [Key.parentID: parentTable.uniqueID, Key.name: name]
		insertRow(d, insertType: .normal, in: database)
		let uniqueID = Int(database.lastInsertRowId())
		return ODBTable(uniqueID: uniqueID, name: name, parentTable: parentTable, isRootTable: false, odb: odb)
	}

	func deleteTable(uniqueID: Int, database: FMDatabase) {
		database.rs_deleteRowsWhereKey(Key.uniqueID, equalsValue: uniqueID, tableName: name)
	}

	func deleteChildTables(parentUniqueID: Int, database: FMDatabase) {
		database.rs_deleteRowsWhereKey(Key.parentID, equalsValue: parentUniqueID, tableName: name)
	}
}

private extension ODBTablesTable {

	func createTable(with row: FMResultSet, parentTable: ODBTable, odb: ODB) -> ODBTable? {

		guard let name = row.string(forColumn: Key.name) else {
			return nil
		}
		let uniqueID = Int(row.longLongInt(forColumn: Key.uniqueID))

		return ODBTable(uniqueID: uniqueID, name: name, parentTable: parentTable, isRootTable: false, odb: odb)
	}
}
