//
//  AddCustomSmartFeedController.swift
//  NetNewsWire
//
//  Created by Mateusz on 17/03/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import RSTree
import Account
import SwiftUI

final class AddCustomSmartFeedController {
	private let hostWindow: NSWindow
	
	init(hostWindow: NSWindow) {
		self.hostWindow = hostWindow
	}
	
	func showAddFeedSheet(_ urlString: String? = nil, _ name: String? = nil, _ account: Account? = nil, _ folder: Folder? = nil) {
		let sheetWindow = NSWindow(
			contentRect: .zero,
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)
		
		let modalView = CreateCustomSmartFeedView(
			dismiss: { result in
				self.hostWindow.endSheet(sheetWindow)
				guard let result else { return }
				let smartFeed = SmartFeed(delegate: CustomSmartFeedDelegate(
					feedName: result.feedName, conjunction: result.conjunction, expressions: result.expressions
				))
				SmartFeedsController.shared.smartFeeds.append(smartFeed)
				NotificationCenter.default.post(
					name: .UserDidAddCustomSmartFeed,
					object: self,
					userInfo: [UserInfoKey.customSmartFeed: smartFeed]
				)
			}
		)
		let hostingController = NSHostingController(rootView: modalView)
		
		sheetWindow.contentViewController = hostingController
		sheetWindow.isReleasedWhenClosed = false
		
		hostWindow.beginSheet(sheetWindow, completionHandler: nil)
	}
}
