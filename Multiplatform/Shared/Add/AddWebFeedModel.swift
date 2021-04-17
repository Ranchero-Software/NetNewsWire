//
//  AddWebFeedModel.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 4/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import RSCore
import SwiftUI

enum AddWebFeedError: LocalizedError {
	
	case none, alreadySubscribed, initialDownload, noFeeds
	
	var errorDescription: String? {
		switch self {
		case .alreadySubscribed:
			return NSLocalizedString("Can’t add this feed because you’ve already subscribed to it.", comment: "Feed finder")
		case .initialDownload:
			return NSLocalizedString("Can’t add this feed because of a download error.", comment: "Feed finder")
		case .noFeeds:
			return NSLocalizedString("Can’t add a feed because no feed was found.", comment: "Feed finder")
		default:
			return nil
		}
	}
	
}

class AddWebFeedModel: ObservableObject {
	
	@Published var shouldDismiss: Bool = false
	@Published var providedURL: String = ""
	@Published var providedName: String = ""
	@Published var selectedFolderIndex: Int = 0
	@Published var addFeedError: AddWebFeedError? {
		didSet {
			addFeedError != AddWebFeedError.none ? (showError = true) : (showError = false)
		}
	}
	@Published var showError: Bool = false
	@Published var containers: [Container] = []
	@Published var showProgressIndicator: Bool = false
	
	init() {
		for account in AccountManager.shared.sortedActiveAccounts {
			containers.append(account)
			if let sortedFolders = account.sortedFolders {
				containers.append(contentsOf: sortedFolders)
			}
		}
	}

	func pasteUrlFromPasteboard() {
		guard let stringFromPasteboard = urlStringFromPasteboard, stringFromPasteboard.mayBeURL else {
			return
		}
		providedURL = stringFromPasteboard
	}
	
	#if os(macOS)
	var urlStringFromPasteboard: String? {
		if let urlString = NSPasteboard.urlString(from: NSPasteboard.general) {
			return urlString.normalizedURL
		}
		return nil
	}
	#else
	var urlStringFromPasteboard: String? {
		if let urlString = UIPasteboard.general.url?.absoluteString {
			return urlString.normalizedURL
		}
		return nil
	}
	#endif
	
	struct AccountAndFolderSpecifier {
		let account: Account
		let folder: Folder?
	}

	func accountAndFolderFromContainer(_ container: Container) -> AccountAndFolderSpecifier? {
		if let account = container as? Account {
			return AccountAndFolderSpecifier(account: account, folder: nil)
		}
		if let folder = container as? Folder, let account = folder.account {
			return AccountAndFolderSpecifier(account: account, folder: folder)
		}
		return nil
	}
	
	func addWebFeed() {
		if let account = accountAndFolderFromContainer(containers[selectedFolderIndex])?.account {
			
			showProgressIndicator = true
			
			let normalizedURLString = providedURL.normalizedURL
			
			guard !normalizedURLString.isEmpty, let url = URL(string: normalizedURLString) else {
				showProgressIndicator = false
				return
			}
			
			let container = containers[selectedFolderIndex]
			
			if account.hasWebFeed(withURL: normalizedURLString) {
				addFeedError = .alreadySubscribed
				showProgressIndicator = false
				return
			}
			
			account.createWebFeed(url: url.absoluteString, name: providedName, container: container, validateFeed: true, completion: { [weak self] result in
				self?.showProgressIndicator = false
				switch result {
				case .success(let feed):
					NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.webFeed: feed])
					self?.shouldDismiss = true
				case .failure(let error):
					switch error {
					case AccountError.createErrorAlreadySubscribed:
						self?.addFeedError = .alreadySubscribed
						return
					case AccountError.createErrorNotFound:
						self?.addFeedError = .noFeeds
						return
					default:
						print("Error")
					}
				}
			})
		}
	}
	
	func smallIconImage(for container: Container) -> RSImage? {
		if let smallIconProvider = container as? SmallIconProvider {
			return smallIconProvider.smallIcon?.image
		}
		return nil
	}
	
}
