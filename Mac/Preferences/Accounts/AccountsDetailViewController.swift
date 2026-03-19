//
//  AccountsDetailViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import SwiftUI
import Account

final class AccountsDetailViewController: NSViewController {

	private let account: Account
	private var accountsWindowController: NSWindowController?

	init(account: Account) {
		self.account = account
		super.init(nibName: nil, bundle: nil)
	}

	public required init?(coder: NSCoder) {
		fatalError("AccountsDetailViewController does not support init(coder:)")
	}

	override func loadView() {
		let detailView = AccountsDetailView(account: account) { [weak self] in
			self?.showCredentials()
		}
		let hostingView = NSHostingView(rootView: detailView)
		self.view = hostingView
	}

	private func showCredentials() {
		guard let window = view.window else {
			return
		}

		switch account.type {
		case .feedbin:
			let accountsFeedbinWindowController = AccountsFeedbinWindowController()
			accountsWindowController = accountsFeedbinWindowController
			accountsFeedbinWindowController.account = account
			accountsFeedbinWindowController.runSheetOnWindow(window)

		case .inoreader, .bazQux, .theOldReader, .freshRSS:
			let accountsReaderAPIWindowController = AccountsReaderAPIWindowController()
			accountsWindowController = accountsReaderAPIWindowController
			accountsReaderAPIWindowController.accountType = account.type
			accountsReaderAPIWindowController.account = account
			accountsReaderAPIWindowController.runSheetOnWindow(window)

		case .newsBlur:
			let accountsNewsBlurWindowController = AccountsNewsBlurWindowController()
			accountsWindowController = accountsNewsBlurWindowController
			accountsNewsBlurWindowController.account = account
			accountsNewsBlurWindowController.runSheetOnWindow(window)

		default:
			break
		}
	}
}
