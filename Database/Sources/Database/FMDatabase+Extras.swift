//
//  File.swift
//  
//
//  Created by Brent Simmons on 3/10/24.
//

import Foundation
import FMDB

public extension FMDatabase {

	static func openAndSetUpDatabase(path: String) -> FMDatabase {

		let database = FMDatabase(path: path)!

		database.open()
		database.executeStatements("PRAGMA synchronous = 1;")
		database.setShouldCacheStatements(true)

		return database
	}

	func executeUpdateInTransaction(_ sql : String, withArgumentsIn parameters: [Any]?) {

		beginTransaction()
		executeUpdate(sql, withArgumentsIn: parameters)
		commit()
	}

	func vacuum() {

		executeStatements("vacuum;")
	}

	func runCreateStatements(_ statements: String) {

		statements.enumerateLines { (line, stop) in
			if line.lowercased().hasPrefix("create") {
				self.executeStatements(line)
			}
			stop = false
		}
	}

	func insertRows(_ dictionaries: [DatabaseDictionary], insertType: RSDatabaseInsertType, tableName: String) {

		for dictionary in dictionaries {
			_ = rs_insertRow(with: dictionary, insertType: insertType, tableName: tableName)
		}
	}
}
