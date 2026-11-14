//
//  SidebarSettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/15/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

final class SidebarSettingsViewController: UITableViewController {

	private enum Section: Int, CaseIterable {
		case feedIcons
		case smartFeeds
	}

	private let showFeedIconsSwitch = UISwitch()
	private let showTodaySwitch = UISwitch()
	private let showAllUnreadSwitch = UISwitch()
	private let showStarredSwitch = UISwitch()

	private var cells = [Section: [UITableViewCell]]()

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

		cells[.feedIcons] = [
			makeCell(switch: showFeedIconsSwitch, title: NSLocalizedString("Show Feed Icons", comment: "Show Feed Icons"), action: #selector(switchShowFeedIcons(_:)))
		]
		cells[.smartFeeds] = [
			makeCell(switch: showTodaySwitch, title: NSLocalizedString("Show Today", comment: "Show Today"), action: #selector(switchShowToday(_:))),
			makeCell(switch: showAllUnreadSwitch, title: NSLocalizedString("Show All Unread", comment: "Show All Unread"), action: #selector(switchShowAllUnread(_:))),
			makeCell(switch: showStarredSwitch, title: NSLocalizedString("Show Starred", comment: "Show Starred"), action: #selector(switchShowStarred(_:)))
		]

		updateShowFeedIconsSwitch()
		updateSmartFeedsSwitches()
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		Section.allCases.count
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch Section(rawValue: section) {
		case .smartFeeds:
			NSLocalizedString("Smart Feeds", comment: "Smart Feeds group title")
		case .feedIcons, nil:
			nil
		}
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		cellsInSection(section).count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		cellsInSection(indexPath.section)[indexPath.row]
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

	func cellsInSection(_ section: Int) -> [UITableViewCell] {
		guard let section = Section(rawValue: section) else {
			return []
		}
		return cells[section] ?? []
	}

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
