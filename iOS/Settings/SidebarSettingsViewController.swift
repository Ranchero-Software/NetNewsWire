//
//  SidebarSettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/15/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

final class SidebarSettingsViewController: UITableViewController {

	private enum Row: Int, CaseIterable {
		case showFeedIcons
		case showToday
		case showAllUnread
		case showStarred
	}

	private let showFeedIconsSwitch = UISwitch()
	private let showTodaySwitch = UISwitch()
	private let showAllUnreadSwitch = UISwitch()
	private let showStarredSwitch = UISwitch()

	private var cells = [UITableViewCell]()

	init() {
		super.init(style: .insetGrouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("Sidebar", comment: "Sidebar")

		NotificationCenter.default.addObserver(self, selector: #selector(handleSidebarShowsIconsDidChange(_:)), name: .sidebarShowsIconsDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleSidebarSmartFeedsVisibilityDidChange(_:)), name: .sidebarSmartFeedsVisibilityDidChange, object: nil)

		let switchesAndTitles: [(UISwitch, String, Selector)] = [
			(showFeedIconsSwitch, NSLocalizedString("Show Feed Icons", comment: "Show Feed Icons"), #selector(switchShowFeedIcons(_:))),
			(showTodaySwitch, NSLocalizedString("Show Today", comment: "Show Today"), #selector(switchShowToday(_:))),
			(showAllUnreadSwitch, NSLocalizedString("Show All Unread", comment: "Show All Unread"), #selector(switchShowAllUnread(_:))),
			(showStarredSwitch, NSLocalizedString("Show Starred", comment: "Show Starred"), #selector(switchShowStarred(_:)))
		]
		cells = switchesAndTitles.map { makeCell(switch: $0.0, title: $0.1, action: $0.2) }

		updateShowFeedIconsSwitch()
		updateSmartFeedsSwitches()
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return cells.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return cells[indexPath.row]
	}

	// MARK: - Actions

	@objc func switchShowFeedIcons(_ sender: UISwitch) {
		AppDefaults.sidebarShowsIcons = sender.isOn
	}

	@objc func switchShowToday(_ sender: UISwitch) {
		AppDefaults.showTodayFeed = sender.isOn
	}

	@objc func switchShowAllUnread(_ sender: UISwitch) {
		AppDefaults.showUnreadFeed = sender.isOn
	}

	@objc func switchShowStarred(_ sender: UISwitch) {
		AppDefaults.showStarredFeed = sender.isOn
	}

	// MARK: - Notifications

	@objc func handleSidebarShowsIconsDidChange(_ notification: Notification) {
		updateShowFeedIconsSwitch()
	}

	@objc func handleSidebarSmartFeedsVisibilityDidChange(_ notification: Notification) {
		updateSmartFeedsSwitches()
	}
}

// MARK: - Private

private extension SidebarSettingsViewController {

	func makeCell(switch toggle: UISwitch, title: String, action: Selector) -> UITableViewCell {
		let cell = VibrantTableViewCell(style: .default, reuseIdentifier: nil)
		cell.selectionStyle = .none
		cell.textLabel?.text = title
		cell.textLabel?.numberOfLines = 0
		cell.textLabel?.adjustsFontForContentSizeCategory = true
		toggle.onTintColor = Assets.Colors.primaryAccent
		toggle.addTarget(self, action: action, for: .valueChanged)
		cell.accessoryView = toggle
		return cell
	}

	func updateShowFeedIconsSwitch() {
		showFeedIconsSwitch.isOn = AppDefaults.sidebarShowsIcons
	}

	func updateSmartFeedsSwitches() {
		showTodaySwitch.isOn = AppDefaults.showTodayFeed
		showAllUnreadSwitch.isOn = AppDefaults.showUnreadFeed
		showStarredSwitch.isOn = AppDefaults.showStarredFeed
	}
}
