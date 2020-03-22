//
//  CloudKitRecordConvertable.swift
//  Account
//
//  Created by Maurice Parker on 3/21/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit

protocol CloudKitRecordConvertible {
    static var cloudKitRecordType: String { get }
    static var cloudKitZoneID: CKRecordZone.ID { get }
	
	var cloudKitPrimaryKey: String { get }
    var recordID: CKRecord.ID { get }
	var cloudKitRecord: CKRecord { get }
	
	func assignCloudKitPrimaryKeyIfNecessary()
}

extension CloudKitRecordConvertible {
    
    public static var cloudKitRecordType: String {
		return String(describing: self)
    }
    
    public var recordID: CKRecord.ID {
		return CKRecord.ID(recordName: cloudKitPrimaryKey, zoneID: Self.cloudKitZoneID)
	}
    
}
