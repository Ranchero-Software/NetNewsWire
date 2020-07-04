//
//  FeedsSettingsModel.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 04/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import SwiftUI
import Account

class FeedsSettingsModel: ObservableObject {
	@Published var showingImportActionSheet = false
	@Published var showingExportActionSheet = false
	@Published var exportingFilePath = ""

	func onTapExportOPML(action: ((Account?) -> Void)) {
		if AccountManager.shared.accounts.count == 1 {
			action(AccountManager.shared.accounts.first)
		}
		else {
			showingExportActionSheet = true
		}
	}

	func onTapImportOPML(action: ((Account?) -> Void)) {
		switch AccountManager.shared.activeAccounts.count {
		case 0:
			//TODO:- show error
			return
		case 1:
			action(AccountManager.shared.activeAccounts.first)
		default:
			showingImportActionSheet = true
		}
	}

	func generateExportURL(for account: Account) -> URL? {
		let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
		let filename = "Subscriptions-\(accountName).opml"
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		let opmlString = OPMLExporter.OPMLString(with: account, title: filename)
		do {
			try opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
		} catch {
			//TODO:- show error
			return nil
		}

		return tempFile
	}

	func processImportedFiles(_ urls: [URL],_ account: Account?) {
		urls.forEach{
			account?.importOPML($0, completion: { result in
				switch result {
				case .success:
					break
				case .failure:
					//TODO:- show error
					break
				}
			})
		}
	}
}

