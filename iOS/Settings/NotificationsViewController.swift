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
	
	private lazy var searchController: UISearchController = {
		let searchController = UISearchController(searchResultsController: nil)
		searchController.searchBar.placeholder = NSLocalizedString("Find a feed", comment: "Find a feed")
		searchController.searchBar.searchBarStyle = .minimal
		searchController.delegate = self
		searchController.searchBar.delegate = self
		searchController.searchBar.sizeToFit()
		searchController.obscuresBackgroundDuringPresentation = false
		searchController.hidesNavigationBarDuringPresentation = false
		self.definesPresentationContext = true
		return searchController
	}()
	private var status: UNAuthorizationStatus = .notDetermined
	private var newArticleNotificationFilter: Bool = false {
		didSet {
			filterButton.menu = notificationFilterMenu()
		}
	}
	private var filterButton: UIBarButtonItem!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("New Article Notifications", comment: "Notifications")
		
		notificationsTableView.prefetchDataSource = self
		navigationItem.searchController = searchController
		
		filterButton = UIBarButtonItem(
			title: nil,
			image: AppAssets.filterInactiveImage,
			primaryAction: nil,
			menu: notificationFilterMenu())
		
		navigationItem.rightBarButtonItem = filterButton
		
		reloadNotificationTableView()
		
		NotificationCenter.default.addObserver(self, selector: #selector(reloadNotificationTableView(_:)), name: UIScene.willEnterForegroundNotification, object: nil)
	}
	
	@objc
	private func reloadNotificationTableView(_ sender: Any? = nil) {
		UNUserNotificationCenter.current().getNotificationSettings { settings in
			DispatchQueue.main.async {
				self.status = settings.authorizationStatus
				if self.status != .authorized {
					self.filterButton.isEnabled = false
					self.newArticleNotificationFilter = false
				}
				self.notificationsTableView.reloadData()
			}
		}
	}
	
	private func notificationFilterMenu() -> UIMenu {
		
		if let filterButton = filterButton {
			if newArticleNotificationFilter == true {
				filterButton.image = AppAssets.filterActiveImage
			} else {
				filterButton.image = AppAssets.filterInactiveImage
			}
		}
		
		let menu = UIMenu(title: "",
						  image: nil,
						  identifier: nil,
						  options: [.displayInline],
						  children: [
							UIAction(
								title: NSLocalizedString("Show Feeds with Notifications Enabled", comment: "Feeds with Notifications"),
								image: AppAssets.appBadgeImage,
								identifier: nil,
								discoverabilityTitle: nil,
								attributes: [],
								state: newArticleNotificationFilter ? .on : .off,
								handler: { [weak self] _ in
									self?.newArticleNotificationFilter.toggle()
									self?.notificationsTableView.reloadData()
								})])
		return menu
	}
	
	// MARK: - Feed Filtering
	
	private func sortedWebFeedsForAccount(_ account: Account) -> [WebFeed] {
		return Array(account.flattenedWebFeeds()).sorted(by: { $0.nameForDisplay.caseInsensitiveCompare($1.nameForDisplay) == .orderedAscending })
	}
	
	private func filteredWebFeeds(_ searchText: String? = "", account: Account) -> [WebFeed] {
		sortedWebFeedsForAccount(account).filter { feed in
			return feed.nameForDisplay.lowercased().contains(searchText!.lowercased())
		}
	}
	
	private func feedsWithNotificationsEnabled(_ account: Account) -> [WebFeed] {
		sortedWebFeedsForAccount(account).filter { feed in
			return feed.isNotifyAboutNewArticles == true
		}
	}
	
}

// MARK: - UITableViewDataSource
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
		if searchController.isActive {
			return filteredWebFeeds(searchController.searchBar.text, account: AccountManager.shared.sortedActiveAccounts[section - 1]).count
		} else if newArticleNotificationFilter == true {
			return feedsWithNotificationsEnabled(AccountManager.shared.sortedActiveAccounts[section - 1]).count
		} else {
			return AccountManager.shared.sortedActiveAccounts[section - 1].flattenedWebFeeds().count
		}
		
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.section == 0 {
			let openSettingsCell = tableView.dequeueReusableCell(withIdentifier: "OpenSettingsCell") as! VibrantBasicTableViewCell
			return openSettingsCell
		} else {
			if searchController.isActive {
				let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationsCell") as! NotificationsTableViewCell
				let account = AccountManager.shared.sortedActiveAccounts[indexPath.section - 1]
				cell.configure(filteredWebFeeds(searchController.searchBar.text, account: account)[indexPath.row])
				return cell
			} else if newArticleNotificationFilter == true {
				let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationsCell") as! NotificationsTableViewCell
				let account = AccountManager.shared.sortedActiveAccounts[indexPath.section - 1]
				cell.configure(feedsWithNotificationsEnabled(account)[indexPath.row])
				return cell
			} else {
				let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationsCell") as! NotificationsTableViewCell
				let account = AccountManager.shared.sortedActiveAccounts[indexPath.section - 1]
				cell.configure(sortedWebFeedsForAccount(account)[indexPath.row])
				return cell
			}
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


// MARK: - UITableViewDelegate
extension NotificationsViewController: UITableViewDelegate {
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		if indexPath.section == 0 {
			UIApplication.shared.open(URL(string: "\(UIApplication.openSettingsURLString)")!)
		}
	}
	
}


extension NotificationsViewController: UITableViewDataSourcePrefetching {
	
	func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
		for path in indexPaths {
			let account = AccountManager.shared.sortedActiveAccounts[path.section - 1]
			let feed = sortedWebFeedsForAccount(account)[path.row]
			let _ = IconImageCache.shared.imageFor(feed.feedID!)
		}
	}
	
}


// MARK: - UISearchControllerDelegate
extension NotificationsViewController: UISearchControllerDelegate {
	
	func didDismissSearchController(_ searchController: UISearchController) {
		print(#function)
		searchController.isActive = false
		notificationsTableView.reloadData()
	}
	
}

// MARK: - UISearchBarDelegate
extension NotificationsViewController: UISearchBarDelegate {
	
	func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
		searchController.isActive = true
		newArticleNotificationFilter = false
		notificationsTableView.reloadData()
	}
	
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		notificationsTableView.reloadData()
	}
	
}
