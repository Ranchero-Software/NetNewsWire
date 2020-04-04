//
//  CKContainer+Extensions.swift
//  Account
//
//  Created by Maurice Parker on 4/4/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit

extension CKContainer {

	private static let userRecordIDKey = "cloudkit.server.userRecordID"
	
    var userRecordID: String? {
        get {
			return UserDefaults.standard.string(forKey: Self.userRecordIDKey)
        }
        set {
            guard let userRecordID = newValue else {
                UserDefaults.standard.removeObject(forKey: Self.userRecordIDKey)
                return
            }
            UserDefaults.standard.set(userRecordID, forKey: Self.userRecordIDKey)
        }
    }
	
	func fetchUserRecordID() {
		guard userRecordID == nil else { return }
		fetchUserRecordID { recordID, error in
			guard let recordID = recordID, error == nil else {
				return
			}
			self.userRecordID = recordID.recordName
		}
	}
	
}
