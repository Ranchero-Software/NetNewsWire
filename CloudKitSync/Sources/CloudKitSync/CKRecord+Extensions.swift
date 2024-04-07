//
//  CKRecord+Extensions.swift
//  Account
//
//  Created by Maurice Parker on 3/29/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit

public extension CKRecord {

	public var externalID: String {
		return recordID.externalID
	}
}

public extension CKRecord.ID {

	public var externalID: String {
		return recordName
	}
}
