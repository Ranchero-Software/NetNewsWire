//
//  ODBValuesTable.swift
//  RSDatabase
//
//  Created by Brent Simmons on 4/20/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSDatabaseObjC

final class ODBValuesTable: DatabaseTable {

	let name = "odb_values"

	private struct Key {
		static let uniqueID = "id"
		static let parentID = "odb_table_id"
		static let name = "name"
		static let primitiveType = "primitive_type"
		static let applicationType = "application_type"
		static let value = "value"
	}

	func fetchValueObjects(of table: ODBTable, database: FMDatabase) -> Set<ODBValueObject> {
		guard let rs = database.rs_selectRowsWhereKey(Key.parentID, equalsValue: table.uniqueID, tableName: name) else {
			return Set<ODBValueObject>()
		}
		return rs.mapToSet{ valueObject(with: $0, parentTable: table) }
	}

	func deleteObject(uniqueID: Int, database: FMDatabase) {
		database.rs_deleteRowsWhereKey(Key.uniqueID, equalsValue: uniqueID, tableName: name)
	}

	func deleteChildObjects(parentUniqueID: Int, database: FMDatabase) {
		database.rs_deleteRowsWhereKey(Key.parentID, equalsValue: parentUniqueID, tableName: name)
	}

	func insertValueObject(name: String, value: ODBValue, parentTable: ODBTable, database: FMDatabase) -> ODBValueObject {

		var d: DatabaseDictionary = [Key.parentID: parentTable.uniqueID, Key.name: name, Key.primitiveType: value.primitiveType.rawValue, Key.value: value.rawValue]
		if let applicationType = value.applicationType {
			d[Key.applicationType] = applicationType
		}

		insertRow(d, insertType: .normal, in: database)
		let uniqueID = Int(database.lastInsertRowId())
		return ODBValueObject(uniqueID: uniqueID, parentTable: parentTable, name: name, value: value)
	}
}

private extension ODBValuesTable {

	func valueObject(with row: FMResultSet, parentTable: ODBTable) -> ODBValueObject? {

		guard let value = value(with: row) else {
			return nil
		}
		guard let name = row.string(forColumn: Key.name) else {
			return nil
		}
		let uniqueID = Int(row.longLongInt(forColumn: Key.uniqueID))

		return ODBValueObject(uniqueID: uniqueID, parentTable: parentTable, name: name, value: value)
	}

	func value(with row: FMResultSet) -> ODBValue? {

		guard let primitiveType = ODBValue.PrimitiveType(rawValue: Int(row.longLongInt(forColumn: Key.primitiveType))) else {
			return nil
		}
		var value: Any? = nil

		switch primitiveType {
		case .boolean:
			value = row.bool(forColumn: Key.value)
		case .integer:
			value = Int(row.longLongInt(forColumn: Key.value))
		case .double:
			value = row.double(forColumn: Key.value)
		case .string:
			value = row.string(forColumn: Key.value)
		case .data:
			value = row.data(forColumn: Key.value)
		case .date:
			value = row.date(forColumn: Key.value)
		}

		guard let fetchedValue = value else {
			return nil
		}
		
		let applicationType = row.string(forColumn: Key.applicationType)
		return ODBValue(rawValue: fetchedValue, primitiveType: primitiveType, applicationType: applicationType)
	}
}
