//
//  NNW3FeedsImporter.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import RSCore

struct NNW3FeedsImporter {
	
	static func importIfNeeded(_ isFirstRun: Bool, account: Account) {
		guard shouldImportDefaultFeeds(isFirstRun) else {
			return
		}

		if !FileManager.default.fileExists(atPath: NNW3PlistConverter.defaultFilePath) {
			return
		}
		
		appDelegate.logDebugMessage("Importing NNW3 feeds.")
		
		let url = URL(fileURLWithPath: NNW3PlistConverter.defaultFilePath)
		guard let opmlURL = NNW3PlistConverter.convertToOPML(url: url) else {
			return
		}
		
		account.importOPML(opmlURL) { result in
			try? FileManager.default.removeItem(at: opmlURL)
			switch result {
			case .success:
				appDelegate.logDebugMessage("Importing NNW3 feeds succeeded.")
			case .failure(let error):
				appDelegate.logDebugMessage("Importing NNW3 feeds failed.  \(error.localizedDescription)")
			}
		}

	}

	private static func shouldImportDefaultFeeds(_ isFirstRun: Bool) -> Bool {
		if !isFirstRun || AccountManager.shared.anyAccountHasAtLeastOneFeed() {
			return false
		}
		return true
	}
	
}
