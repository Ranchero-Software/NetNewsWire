//
//  AccountInfo.swift
//  Database
//
//  Created by Brent Simmons on 7/3/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSDatabase
import Data

// This allows for serializing structures such as Author, Attachment, and AccountInfo
// without having to create separate tables and lookup tables.
// While there are good strong arguments for using separate tables,
// we decided that the relative simplicity this allows is worth it.

struct PropertyListTransformer {
	
	static func accountInfoWithRow(_ row: FMResultSet) -> AccountInfo? {
		
		guard let rawAccountInfo = row.data(forColumn: DatabaseKey.accountInfo) else {
			return nil
		}
		return propertyList(withData: rawAccountInfo) as? AccountInfo
	}
	
	static func tagsWithRow(_ row: FMResultSet) -> [String]? {
		
		guard let d = row.data(forColumn: DatabaseKey.tags) else {
			return nil
		}
		return propertyList(withData: d) as? [String]
	}
	
	static func attachmentsWithRow(_ row: FMResultSet) -> [Attachment]? {
		
		guard let d = row.data(forColumn: DatabaseKey.attachments) else {
			return nil
		}
		guard let plist = propertyList(withData: d) as? [Any] else {
			return nil
		}
		return Attachment.attachments(with: plist)
	}
	
	static func propertyListWithRow(_ row: FMResultSet, column: String) -> Any? {
		
		guard let rawData = row.data(forColumn: column) else {
			return nil
		}
		return propertyList(withData: rawData)
	}
	
	static func propertyList(withData data: Data) -> Any? {
		
		do {
			return try PropertyListSerialization.propertyList(fromData: rawAccountInfo, options: [], format: nil)
		} catch {
			return nil
		}
	}
	
	static func data(withPropertyList plist: Any) -> Data? {
	
		do {
			return try PropertyListSerialization.data(from: plist, format: .binary, options: [])
		}
		catch {
			return nil
		}
	}
}
