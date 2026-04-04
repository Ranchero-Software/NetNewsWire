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
		let detailView = AccountsDetailView(
			account: account,
			onCredentials: { [weak self] in
				self?.showCredentials()
			},
			onHideReadOverrides: { [weak self] in
				self?.showHideReadArticlesSettings()
			}
		)
		let hostingView = NSHostingView(rootView: detailView)
		self.view = hostingView
	}

	private func showHideReadArticlesSettings() {
		guard let window = view.window else {
			return
		}

		let overridesView = FeedReadFilterOverridesView(
			account: account,
			hasOverride: { [weak self] feedID in
				guard let accountID = self?.account.accountID else {
					return false
				}
				return AppDefaults.shared.feedReadFilterOverrides.hasOverride(accountID: accountID, feedID: feedID)
			},
			setOverride: { [weak self] feedID, hasOverride in
				guard let accountID = self?.account.accountID else {
					return
				}
				var overrides = AppDefaults.shared.feedReadFilterOverrides

				if hasOverride {
					let globalHides = AppDefaults.shared.hideReadArticles
					overrides.setOverride(accountID: accountID, feedID: feedID, globalHides ? .show : .hide)
				} else {
					overrides.clearOverride(accountID: accountID, feedID: feedID)
				}

				AppDefaults.shared.feedReadFilterOverrides = overrides
			},
			clearAllOverrides: { [weak self] in
				guard let accountID = self?.account.accountID else {
					return
				}
				var overrides = AppDefaults.shared.feedReadFilterOverrides
				overrides.clearAll(accountID: accountID)
				AppDefaults.shared.feedReadFilterOverrides = overrides
			}
		)

		var viewWithDone = overridesView
		viewWithDone.onDone = { [weak window] in
			guard let window, let sheet = window.attachedSheet else {
				return
			}
			window.endSheet(sheet)
		}

		let hostingController = NSHostingController(rootView: viewWithDone)
		let sheetWindow = NSWindow(contentViewController: hostingController)
		sheetWindow.title = "Hide Read Articles Settings"
		window.beginSheet(sheetWindow)
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
