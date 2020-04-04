//
//  CloudKitPublicZone.swift
//  Account
//
//  Created by Maurice Parker on 4/4/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import CloudKit
import os.log

final class CloudKitPublicZone: CloudKitZone {
	
	static var zoneID: CKRecordZone.ID {
		return CKRecordZone.default().zoneID
	}
	
	var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "CloudKit")
	
	weak var container: CKContainer?
	weak var database: CKDatabase?
	var delegate: CloudKitZoneDelegate?
	
	struct CloudKitWebFeed {
		static let recordType = "WebFeed"
		struct Fields {
			static let url = "url"
			static let httpLastModified = "httpLastModified"
			static let httpEtag = "httpEtag"
		}
	}
	
	struct CloudKitWebFeedCheck {
		static let recordType = "UserSubscription"
		struct Fields {
			static let webFeed = "webFeed"
			static let subscriptionID = "oldestPossibleCheckTime"
		}
	}
	
	struct CloudKitUserSubscription {
		static let recordType = "UserSubscription"
		struct Fields {
			static let user = "user"
			static let webFeed = "webFeed"
			static let subscriptionID = "subscriptionID"
		}
	}
	
	func subscribe() {}
	
	func receiveRemoteNotification(userInfo: [AnyHashable : Any], completion: @escaping () -> Void) {
		
	}
	

}
