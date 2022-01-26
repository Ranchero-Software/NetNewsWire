//
//  NotificationsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 26/01/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import UserNotifications

class NotificationsViewController: UIViewController {

	@IBOutlet weak var notificationsTableView: UITableView!
	private var status: UNAuthorizationStatus = .notDetermined
	
	
    override func viewDidLoad() {
        super.viewDidLoad()
		self.title = NSLocalizedString("Notifications", comment: "Notifications")
		notificationsTableView.sectionHeaderTopPadding = 15
		UNUserNotificationCenter.current().getNotificationSettings { settings in
			DispatchQueue.main.async {
				self.status = settings.authorizationStatus
				self.notificationsTableView.reloadData()
			}
		}
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
    }
	
	@objc
	private func faviconDidBecomeAvailable(_ sender: Any) {
		notificationsTableView.reloadData()
	}
	
	@objc
	private func webFeedIconDidBecomeAvailable(_ sender: Any) {
		notificationsTableView.reloadData()
	}
	
	private func sortedWebFeedsForAccount(_ account: Account) -> [WebFeed] {
		return Array(account.flattenedWebFeeds()).sorted(by: { $0.nameForDisplay.caseInsensitiveCompare($1.nameForDisplay) == .orderedAscending })
	}
    
}

// MARK: UITableViewDataSource
extension NotificationsViewController: UITableViewDataSource {
	
	func numberOfSections(in tableView: UITableView) -> Int {
		/// 1 section for enabling notifications
		/// + number of active accounts
		return 1 + AccountManager.shared.activeAccounts.count
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 { return 1 }
		return AccountManager.shared.sortedActiveAccounts[section - 1].flattenedWebFeeds().count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationsCell") as! NotificationsTableViewCell
		
		if indexPath.section == 0 {
			cell.configure(status)
		} else {
			let account = AccountManager.shared.sortedActiveAccounts[indexPath.section - 1]
			let feed = sortedWebFeedsForAccount(account)[indexPath.row]
			cell.configure(feed, status)
		}
		
		return cell
	}
	
	
	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == 0 { return NSLocalizedString("Enable Notifications", comment: "Enable Notifications") }
		return AccountManager.shared.sortedActiveAccounts[section - 1].nameForDisplay
	}
	
	func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if section == 0 {
			if status == .denied {
				return NSLocalizedString("Notification permissions are currently denied. Enable notifications in the Settings app.", comment: "Notifications denied.")
			}
		}
		return nil
	}
}

extension NotificationsViewController: UITableViewDelegate {
	
	
	
	
}
