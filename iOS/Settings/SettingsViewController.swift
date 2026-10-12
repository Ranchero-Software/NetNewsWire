//
//  SettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import CoreServices
import SafariServices
import SwiftUI
import RSCore
import Account
import ActivityLog

final class SettingsViewController: UITableViewController {

	private enum Section: Int {
		case notifications = 0
		case accounts = 1
		case feeds = 2
		case timeline = 3
		case articles = 4
		case appearance = 5
		case troubleshooting = 6
		case help = 7
	}

	private enum TroubleshootingRow: Int {
		case errorLog = 0
		case activityLog = 1
		case accountStats = 2
		case dinosaurs = 3
		case cloudKitZoneStats = 4
	}

	private enum FeedsRow: Int {
		case importSubscriptions = 0
		case exportSubscriptions = 1
		case addNetNewsWireNewsFeed = 2
	}

	private enum TimelineRow: Int {
		case sortOrder = 0
		case groupByFeed = 1
		case refreshClearsReadArticles = 2
		case confirmMarkAllAsRead = 3
		case timelineLayout = 4
	}

	private enum ArticlesRow: Int, CaseIterable {
		case theme = 0
		case openLinksInNetNewsWire = 1
		case enableJavaScript = 2
		case enableFullScreenArticles = 3
	}

	private enum HelpRow: Int {
		case help = 0
		case forum = 1
		case releaseNotes = 2
		case bugTracker = 3
		case about = 4
	}

	private lazy var opmlController = OPMLImportExportController(presentingViewController: self)

	@IBOutlet var timelineSortOrderSwitch: UISwitch!
	@IBOutlet var groupByFeedSwitch: UISwitch!
	@IBOutlet var refreshClearsReadArticlesSwitch: UISwitch!
	@IBOutlet var articleThemeDetailLabel: UILabel!
	@IBOutlet var confirmMarkAllAsReadSwitch: UISwitch!
	@IBOutlet var showFullscreenArticlesSwitch: UISwitch!
	@IBOutlet var colorPaletteCell: UITableViewCell?
	@IBOutlet var unreadCountDisplayCell: UITableViewCell?
	@IBOutlet var openLinksInNetNewsWire: UISwitch!
	@IBOutlet var enableJavaScriptSwitch: UISwitch!

	var scrollToArticlesSection = false
	weak var presentingParentController: UIViewController?

	private lazy var colorPalettePopUpButton = Self.makePopUpButton()
	private lazy var unreadCountDisplayPopUpButton = Self.makePopUpButton()

	override func viewDidLoad() {
		// This hack mostly works around a bug in static tables with dynamic type.  See: https://spin.atomicobject.com/2018/10/15/dynamic-type-static-uitableview/
		NotificationCenter.default.removeObserver(tableView!, name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUserInterfaceColorPaletteDidUpdate(_:)), name: .userInterfaceColorPaletteDidUpdate, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUnreadCountDisplaySettingDidChange(_:)), name: .unreadCountDisplaySettingDidChange, object: nil)

		tableView.register(UINib(nibName: "SettingsComboTableViewCell", bundle: nil), forCellReuseIdentifier: "SettingsComboTableViewCell")
		tableView.register(UINib(nibName: "SettingsTableViewCell", bundle: nil), forCellReuseIdentifier: "SettingsTableViewCell")

		tableView.rowHeight = UITableView.automaticDimension
		tableView.estimatedRowHeight = 44

		addPopUpButton(colorPalettePopUpButton, to: colorPaletteCell, accessibilityLabel: NSLocalizedString("Color Palette", comment: "Color Palette"))
		addPopUpButton(unreadCountDisplayPopUpButton, to: unreadCountDisplayCell, accessibilityLabel: NSLocalizedString("Unread Counts", comment: "Unread Counts"))
		updateColorPalettePopUpButton()
		updateUnreadCountDisplayPopUpButton()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if AppDefaults.timelineSortDirection == .orderedAscending {
			timelineSortOrderSwitch.isOn = true
		} else {
			timelineSortOrderSwitch.isOn = false
		}

		if AppDefaults.timelineGroupByFeed {
			groupByFeedSwitch.isOn = true
		} else {
			groupByFeedSwitch.isOn = false
		}

		if AppDefaults.refreshClearsReadArticles {
			refreshClearsReadArticlesSwitch.isOn = true
		} else {
			refreshClearsReadArticlesSwitch.isOn = false
		}

		articleThemeDetailLabel.text = ArticleThemesManager.shared.currentTheme.name

		if AppDefaults.confirmMarkAllAsRead {
			confirmMarkAllAsReadSwitch.isOn = true
		} else {
			confirmMarkAllAsReadSwitch.isOn = false
		}

		if AppDefaults.articleFullscreenAvailable {
			showFullscreenArticlesSwitch.isOn = true
		} else {
			showFullscreenArticlesSwitch.isOn = false
		}

		if AppDefaults.isArticleContentJavascriptEnabled {
			enableJavaScriptSwitch.isOn = true
		} else {
			enableJavaScriptSwitch.isOn = false
		}

		openLinksInNetNewsWire.isOn = !AppDefaults.useSystemBrowser

		let buildLabel = CopyableLabel(frame: CGRect(x: 32.0, y: 0.0, width: 0.0, height: 0.0))
		buildLabel.font = UIFont.systemFont(ofSize: 11.0)
		buildLabel.textColor = UIColor.gray
		buildLabel.text = "\(Bundle.main.appName) \(Bundle.main.versionNumber) (build \(Bundle.main.buildNumber))"
		buildLabel.sizeToFit()

		let wrapperView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: buildLabel.frame.height + 10.0))
		wrapperView.addSubview(buildLabel)
		tableView.tableFooterView = wrapperView

	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		self.tableView.selectRow(at: nil, animated: true, scrollPosition: .none)

		if scrollToArticlesSection {
			tableView.scrollToRow(at: IndexPath(row: 0, section: Section.articles.rawValue), at: .top, animated: true)
			scrollToArticlesSection = false
		}

	}

	// MARK: UITableView

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

		switch Section(rawValue: section) {
		case .accounts:
			return AccountManager.shared.accounts.count + 1
		case .feeds:
			let defaultNumberOfRows = super.tableView(tableView, numberOfRowsInSection: section)
			if AccountManager.shared.activeAccounts.isEmpty || AccountManager.shared.anyAccountHasNetNewsWireNewsSubscription() {
				return defaultNumberOfRows - 1
			}
			return defaultNumberOfRows
		case .articles:
			// The Full Screen Articles row is iPhone-only.
			return traitCollection.userInterfaceIdiom == .phone ? ArticlesRow.allCases.count : ArticlesRow.allCases.count - 1
		case .troubleshooting:
			let defaultNumberOfRows = super.tableView(tableView, numberOfRowsInSection: section)
			if !AccountManager.shared.hasiCloudAccount {
				return defaultNumberOfRows - 1
			}
			return defaultNumberOfRows
		default:
			return super.tableView(tableView, numberOfRowsInSection: section)
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

		let cell: UITableViewCell
		switch Section(rawValue: indexPath.section) {
		case .accounts:

			let sortedAccounts = AccountManager.shared.sortedAccounts
			if indexPath.row == sortedAccounts.count {
				cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCell", for: indexPath)
				cell.textLabel?.text = NSLocalizedString("Add Account", comment: "Add Account")
			} else {
				let acctCell = tableView.dequeueReusableCell(withIdentifier: "SettingsComboTableViewCell", for: indexPath) as! SettingsComboTableViewCell
				acctCell.applyThemeProperties()
				let account = sortedAccounts[indexPath.row]
				acctCell.comboImage?.image = Assets.accountImage(account.type)
				acctCell.comboNameLabel?.text = account.nameForDisplay
				cell = acctCell
			}
		default:
			cell = super.tableView(tableView, cellForRowAt: indexPath)

		}

		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

		switch Section(rawValue: indexPath.section) {
		case .notifications:
			UIApplication.shared.open(URL(string: "\(UIApplication.openSettingsURLString)")!)
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		case .accounts:
			let sortedAccounts = AccountManager.shared.sortedAccounts
			if indexPath.row == sortedAccounts.count {
				let addAccountView = AddAccountView(presentationAnchor: view.window) { [weak self] in
					self?.navigationController?.popViewController(animated: false)
				}
				self.navigationController?.pushViewController(UIHostingController(rootView: addAccountView), animated: true)
			} else {
				let controller = UIStoryboard.inspector.instantiateController(ofType: AccountInspectorViewController.self)
				controller.account = sortedAccounts[indexPath.row]
				self.navigationController?.pushViewController(controller, animated: true)
			}
		case .feeds:
			switch FeedsRow(rawValue: indexPath.row) {
			case .importSubscriptions:
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
				opmlController.importOPML(sourceRect: tableView.rectForRow(at: indexPath))
			case .exportSubscriptions:
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
				opmlController.exportOPML(sourceRect: tableView.rectForRow(at: indexPath))
			case .addNetNewsWireNewsFeed:
				addFeed()
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			default:
				break
			}
		case .timeline:
			switch TimelineRow(rawValue: indexPath.row) {
			case .timelineLayout:
				let timeline = UIStoryboard.settings.instantiateController(ofType: TimelineCustomizerCollectionViewController.self)
				self.navigationController?.pushViewController(timeline, animated: true)
			default:
				break
			}
		case .articles:
			switch ArticlesRow(rawValue: indexPath.row) {
			case .theme:
				let articleThemes = UIStoryboard.settings.instantiateController(ofType: ArticleThemesTableViewController.self)
				self.navigationController?.pushViewController(articleThemes, animated: true)
			default:
				break
			}
		case .troubleshooting:
			let viewController: UIViewController? = {
				switch TroubleshootingRow(rawValue: indexPath.row) {
				case .errorLog:
					return UIHostingController(rootView: ErrorLogView())
				case .accountStats:
					return UIHostingController(rootView: AccountStatsView())
				case .cloudKitZoneStats:
					return UIHostingController(rootView: CloudKitStatsView())
				case .activityLog:
					return UIHostingController(rootView: ActivityLogView())
				case .dinosaurs:
					return UIHostingController(rootView: DinosaursView(dismissAndPresent: { [weak self] dinosaur in
						guard let self else {
							return
						}
						self.dismiss(animated: true) {
							if let rootSplit = self.presentingParentController as? RootSplitViewController {
								rootSplit.coordinator.discloseFeed(dinosaur.feed, animations: [.scroll, .navigation])
							}
						}
					}))
				default:
					return nil
				}
			}()
			if let viewController {
				self.navigationController?.pushViewController(viewController, animated: true)
			}
		case .help:
			switch HelpRow(rawValue: indexPath.row) {
			case .help:
				openURL(HelpURL.helpHome.rawValue)
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case .forum:
				openURL(HelpURL.discourse.rawValue)
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case .releaseNotes:
				openURL(HelpURL.releaseNotes.rawValue)
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case .bugTracker:
				openURL(HelpURL.bugTracker.rawValue)
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case .about:
				let hosting = UIHostingController(rootView: AboutView())
				self.navigationController?.pushViewController(hosting, animated: true)
			default:
				break
			}
		default:
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		}
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return false
	}

	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		return false
	}

	override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
		return .none
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return UITableView.automaticDimension
	}

	override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
		return super.tableView(tableView, indentationLevelForRowAt: IndexPath(row: 0, section: Section.accounts.rawValue))
	}

	// MARK: Actions

	@IBAction func done(_ sender: Any) {
		dismiss(animated: true)
	}

	@IBAction func switchTimelineOrder(_ sender: Any) {
		if timelineSortOrderSwitch.isOn {
			AppDefaults.timelineSortDirection = .orderedAscending
		} else {
			AppDefaults.timelineSortDirection = .orderedDescending
		}
	}

	@IBAction func switchGroupByFeed(_ sender: Any) {
		if groupByFeedSwitch.isOn {
			AppDefaults.timelineGroupByFeed = true
		} else {
			AppDefaults.timelineGroupByFeed = false
		}
	}

	@IBAction func switchClearsReadArticles(_ sender: Any) {
		if refreshClearsReadArticlesSwitch.isOn {
			AppDefaults.refreshClearsReadArticles = true
		} else {
			AppDefaults.refreshClearsReadArticles = false
		}
	}

	@IBAction func switchConfirmMarkAllAsRead(_ sender: Any) {
		if confirmMarkAllAsReadSwitch.isOn {
			AppDefaults.confirmMarkAllAsRead = true
		} else {
			AppDefaults.confirmMarkAllAsRead = false
		}
	}

	@IBAction func switchFullscreenArticles(_ sender: Any) {
		if showFullscreenArticlesSwitch.isOn {
			AppDefaults.articleFullscreenAvailable = true
		} else {
			AppDefaults.articleFullscreenAvailable = false
		}
	}

	@IBAction func switchBrowserPreference(_ sender: Any) {
		if openLinksInNetNewsWire.isOn {
			AppDefaults.useSystemBrowser = false
		} else {
			AppDefaults.useSystemBrowser = true
		}
		UIMenuSystem.main.setNeedsRebuild()
	}

	@IBAction func switchJavaScriptPreference(_ sender: Any) {
		AppDefaults.isArticleContentJavascriptEnabled = enableJavaScriptSwitch.isOn
 	}

	// MARK: - Notifications

	@objc func contentSizeCategoryDidChange() {
		tableView.reloadData()
	}

	@objc func accountsDidChange() {
		tableView.reloadData()
	}

	@objc func displayNameDidChange() {
		tableView.reloadData()
	}

	@objc func browserPreferenceDidChange() {
		tableView.reloadData()
	}

	@objc func handleUserInterfaceColorPaletteDidUpdate(_ notification: Notification) {
		updateColorPalettePopUpButton()
	}

	@objc func handleUnreadCountDisplaySettingDidChange(_ notification: Notification) {
		updateUnreadCountDisplayPopUpButton()
	}

}

// MARK: - Private

private extension SettingsViewController {

	static func makePopUpButton() -> UIButton {
		var configuration = UIButton.Configuration.plain()
		configuration.baseForegroundColor = .secondaryLabel
		let button = UIButton(configuration: configuration)
		button.showsMenuAsPrimaryAction = true
		button.changesSelectionAsPrimaryAction = true
		return button
	}

	/// Auto Layout lets the button resize itself when choosing an item changes its title.
	/// The accessibility label names the setting, since the button’s title is only the current choice.
	func addPopUpButton(_ button: UIButton, to cell: UITableViewCell?, accessibilityLabel: String) {
		guard let cell else {
			return
		}
		button.accessibilityLabel = accessibilityLabel
		button.translatesAutoresizingMaskIntoConstraints = false
		button.setContentCompressionResistancePriority(.required, for: .horizontal)
		cell.contentView.addSubview(button)
		NSLayoutConstraint.activate([
			button.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
			button.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
		])
	}

	func updateColorPalettePopUpButton() {
		let currentColorPalette = AppDefaults.userInterfaceColorPalette
		let actions = UserInterfaceColorPalette.allCases.map { colorPalette in
			UIAction(title: String(describing: colorPalette), state: colorPalette == currentColorPalette ? .on : .off) { _ in
				AppDefaults.userInterfaceColorPalette = colorPalette
			}
		}
		colorPalettePopUpButton.menu = UIMenu(children: actions)
		colorPalettePopUpButton.accessibilityValue = String(describing: currentColorPalette)
	}

	func updateUnreadCountDisplayPopUpButton() {
		let currentUnreadCountDisplay = AppDefaults.unreadCountDisplay
		let actions = UnreadCountDisplay.allCases.map { unreadCountDisplay in
			UIAction(title: String(describing: unreadCountDisplay), state: unreadCountDisplay == currentUnreadCountDisplay ? .on : .off) { _ in
				AppDefaults.unreadCountDisplay = unreadCountDisplay
			}
		}
		unreadCountDisplayPopUpButton.menu = UIMenu(children: actions)
		unreadCountDisplayPopUpButton.accessibilityValue = String(describing: currentUnreadCountDisplay)
	}

	func addFeed() {
		self.dismiss(animated: true)

		let addFeedView = AddFeedView(initialFeed: AccountManager.netNewsWireNewsURL, initialFeedName: NSLocalizedString("NetNewsWire News", comment: "NetNewsWire News"))
		let hostingController = UIHostingController(rootView: addFeedView)
		hostingController.modalPresentationStyle = .formSheet
		hostingController.preferredContentSize = UIViewController.formSheetSize

		presentingParentController?.present(hostingController, animated: true)
	}

	func openURL(_ urlString: String) {
		guard let url = URL(string: urlString) else {
			return
		}

		// Open GitHub links in the GitHub app when installed.
		if let host = url.host, host == "github.com" || host.hasSuffix(".github.com") {
			UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { [weak self] openedInApp in
				if !openedInApp {
					self?.presentSafariViewController(for: url)
				}
			}
			return
		}

		presentSafariViewController(for: url)
	}

	private func presentSafariViewController(for url: URL) {
		let vc = SFSafariViewController(url: url)
		vc.modalPresentationStyle = .pageSheet
		present(vc, animated: true)
	}
}
