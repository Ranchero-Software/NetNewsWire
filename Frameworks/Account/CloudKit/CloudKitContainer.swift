//
//  CloudKitContainer.swift
//  Account
//
//  Created by Maurice Parker on 4/4/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit

struct CloudKitContainer {

	private static let userRecordIDKey = "cloudkit.server.userRecordID"
	
    static var userRecordID: String? {
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
	
	static func fetchUserRecordID() {
		guard Self.userRecordID == nil else { return }
		CKContainer.default().fetchUserRecordID { recordID, error in
			guard let recordID = recordID, error == nil else {
				return
			}
			Self.userRecordID = recordID.recordName
		}
	}
	
}
