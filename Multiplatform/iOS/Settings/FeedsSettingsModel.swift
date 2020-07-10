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

enum FeedsSettingsError: LocalizedError, Equatable {
	case none, noActiveAccount, exportFailed(reason: String?), importFailed

	var errorDescription: String? {
		switch self {
		case .noActiveAccount:
			return NSLocalizedString("You must have at least one active account.", comment: "Missing active account")
		case .exportFailed(let reason):
			return reason
		case .importFailed:
			return NSLocalizedString(
				"We were unable to process the selected file. Please ensure that it is a properly formatted OPML file.",
				comment: "Import Failed Message"
			)
		default:
			return nil
		}
	}

	var title: String? {
		switch self {
		case .noActiveAccount:
			return NSLocalizedString("Error", comment: "Error Title")
		case .exportFailed:
			return NSLocalizedString("OPML Export Error", comment: "Export Failed")
		case .importFailed:
			return NSLocalizedString("Import Failed", comment: "Import Failed")
		default:
			return nil
		}
	}
}

class FeedsSettingsModel: ObservableObject {
	@Published var showingImportActionSheet = false
	@Published var showingExportActionSheet = false
	@Published var exportingFilePath = ""
	@Published var feedsSettingsError: FeedsSettingsError? {
		didSet {
			feedsSettingsError != FeedsSettingsError.none ? (showError = true) : (showError = false)
		}
	}
	@Published var showError: Bool = false

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
			feedsSettingsError = .noActiveAccount
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
			feedsSettingsError = .exportFailed(reason: error.localizedDescription)
			return nil
		}

		return tempFile
	}

	func processImportedFiles(_ urls: [URL],_ account: Account?) {
		urls.forEach{
			account?.importOPML($0, completion: { [weak self] result in
				switch result {
				case .success:
					break
				case .failure:
					self?.feedsSettingsError = .importFailed
					break
				}
			})
		}
	}
}

