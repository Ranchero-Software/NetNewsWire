//
//  FeedProvidersAddViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import FeedProvider

class FeedProvidersAddViewController: NSViewController {

	@IBOutlet weak var tableView: NSTableView!
	
	private var accountsAddWindowController: NSWindowController?
	
	#if DEBUG
	private var addableFeedProviderTypes: [FeedProviderType] = [.twitter]
	#else
	private var addableFeedProviderTypes: [FeedProviderType] = [.twitter]
	#endif

	init() {
		super.init(nibName: "FeedProvidersAdd", bundle: nil)
	}
	
	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	override func viewDidLoad() {
        super.viewDidLoad()
		tableView.dataSource = self
		tableView.delegate = self
    }
    
}

// MARK: - NSTableViewDataSource

extension FeedProvidersAddViewController: NSTableViewDataSource {
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return addableFeedProviderTypes.count
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		return nil
	}
}

// MARK: - NSTableViewDelegate

extension FeedProvidersAddViewController: NSTableViewDelegate {
	
	private static let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "AccountCell")
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		
		if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "Cell"), owner: nil) as? FeedProvidersAddTableCellView {
			switch addableFeedProviderTypes[row] {
			case .twitter:
				cell.feedProviderNameLabel?.stringValue = NSLocalizedString("Twitter", comment: "Twitter")
				cell.feedProviderImageView?.image = AppAssets.feedProviderTwitter
			}
			return cell
		}
		return nil
	}
	
	func tableViewSelectionDidChange(_ notification: Notification) {
		
		let selectedRow = tableView.selectedRow
		guard selectedRow != -1 else {
			return
		}

//		switch addableAccountTypes[selectedRow] {
//		case .onMyMac:
//			let accountsAddLocalWindowController = AccountsAddLocalWindowController()
//			accountsAddLocalWindowController.runSheetOnWindow(self.view.window!)
//			accountsAddWindowController = accountsAddLocalWindowController
//		case .cloudKit:
//			let accountsAddCloudKitWindowController = AccountsAddCloudKitWindowController()
//			accountsAddCloudKitWindowController.runSheetOnWindow(self.view.window!) { response in
//				if response == NSApplication.ModalResponse.OK {
//					self.restrictAccounts()
//					self.tableView.reloadData()
//				}
//			}
//			accountsAddWindowController = accountsAddCloudKitWindowController
//		case .feedbin:
//			let accountsFeedbinWindowController = AccountsFeedbinWindowController()
//			accountsFeedbinWindowController.runSheetOnWindow(self.view.window!)
//			accountsAddWindowController = accountsFeedbinWindowController
//		case .feedWrangler:
//			let accountsFeedWranglerWindowController = AccountsFeedWranglerWindowController()
//			accountsFeedWranglerWindowController.runSheetOnWindow(self.view.window!)
//			accountsAddWindowController = accountsFeedWranglerWindowController
//		case .freshRSS:
//			let accountsReaderAPIWindowController = AccountsReaderAPIWindowController()
//			accountsReaderAPIWindowController.accountType = .freshRSS
//			accountsReaderAPIWindowController.runSheetOnWindow(self.view.window!)
//			accountsAddWindowController = accountsReaderAPIWindowController
//		case .feedly:
//			let addAccount = OAuthAccountAuthorizationOperation(accountType: .feedly)
//			addAccount.delegate = self
//			addAccount.presentationAnchor = self.view.window!
//			MainThreadOperationQueue.shared.add(addAccount)
//		case .newsBlur:
//			let accountsNewsBlurWindowController = AccountsNewsBlurWindowController()
//			accountsNewsBlurWindowController.runSheetOnWindow(self.view.window!)
//			accountsAddWindowController = accountsNewsBlurWindowController
//		}
		
		tableView.selectRowIndexes([], byExtendingSelection: false)
		
	}
	
}

// MARK: OAuthAccountAuthorizationOperationDelegate

//extension AccountsAddViewController: OAuthAccountAuthorizationOperationDelegate {
//
//	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account) {
//		account.refreshAll { [weak self] result in
//			switch result {
//			case .success:
//				break
//			case .failure(let error):
//				self?.presentError(error)
//			}
//		}
//	}
//
//	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error) {
//		view.window?.presentError(error)
//	}
//}
