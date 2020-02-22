//
//  AccountMigrator.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/9/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

struct AccountMigrator {
	
	static func migrate() {
		let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as! String
		let containerAccountsURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
		let containerAccountsFolder = containerAccountsURL!.appendingPathComponent("Accounts")
		
		let documentAccountURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		let documentAccountsFolder = documentAccountURL.appendingPathComponent("Accounts")
		
		try? FileManager.default.moveItem(at: containerAccountsFolder, to: documentAccountsFolder)
	}
	
}
