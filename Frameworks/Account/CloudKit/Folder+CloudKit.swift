//
//  Folder+CloudKit.swift
//  Account
//
//  Created by Maurice Parker on 3/21/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit

extension Folder: CloudKitRecordConvertible {

    enum CloudKitKey: String {
        case name
    }
	
	static var cloudKitZoneID: CKRecordZone.ID {
		return CloudKitAccountZone.zoneID
	}
	
	var cloudKitPrimaryKey: String {
		return externalID!
	}

	var cloudKitRecord: CKRecord {
		let record = CKRecord(recordType: Self.cloudKitRecordType)
		record[.name] = name
		return record
	}
	
	func assignCloudKitPrimaryKeyIfNecessary() {
		if externalID == nil {
			externalID = UUID().uuidString
		}
	}
	
}

extension CKRecord {
	subscript(key: Folder.CloudKitKey) -> Any? {
        get {
            return self[key.rawValue]
        }
        set {
            self[key.rawValue] = newValue as? CKRecordValue
        }
    }
}
