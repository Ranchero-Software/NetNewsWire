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
		self.title = NSLocalizedString("NEW_ARTICLE_NOTIFICATIONS", comment: "New Article Notifications")
		notificationsTableView.sectionHeaderTopPadding = 25
		
		NotificationCenter.default.addObserver(self, selector: #selector(reloadNotificationTableView(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(reloadNotificationTableView(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(reloadNotificationTableView(_:)), name: .NotificationPreferencesDidUpdate, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(reloadNotificationTableView(_:)), name: UIScene.willEnterForegroundNotification, object: nil)
		
		reloadNotificationTableView()
	}
	
	@objc
	private func reloadNotificationTableView(_ sender: Any? = nil) {
		UNUserNotificationCenter.current().getNotificationSettings { settings in
			DispatchQueue.main.async {
				self.status = settings.authorizationStatus
				self.notificationsTableView.reloadData()
			}
		}
	}
	
	private func sortedWebFeedsForAccount(_ account: Account) -> [WebFeed] {
		return Array(account.flattenedWebFeeds()).sorted(by: { $0.nameForDisplay.caseInsensitiveCompare($1.nameForDisplay) == .orderedAscending })
	}
    
}

// MARK: UITableViewDataSource
extension NotificationsViewController: UITableViewDataSource {
	
	func numberOfSections(in tableView: UITableView) -> Int {
		if status == .denied { return 1 }
		return 1 + AccountManager.shared.activeAccounts.count
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 {
			if status == .denied { return 1 }
			return 0
		}
		return AccountManager.shared.sortedActiveAccounts[section - 1].flattenedWebFeeds().count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		
		if indexPath.section == 0 {
			let openSettingsCell = tableView.dequeueReusableCell(withIdentifier: "OpenSettingsCell") as! VibrantBasicTableViewCell
			return openSettingsCell
		} else {
			let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationsCell") as! NotificationsTableViewCell
			let account = AccountManager.shared.sortedActiveAccounts[indexPath.section - 1]
			let feed = sortedWebFeedsForAccount(account)[indexPath.row]
			cell.configure(feed, status)
			return cell
		}
	}
	
	
	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == 0 { return nil }
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
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		UIApplication.shared.open(URL(string: "\(UIApplication.openSettingsURLString)")!)
	}
	
	
}
