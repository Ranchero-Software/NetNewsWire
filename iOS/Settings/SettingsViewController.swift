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
import UniformTypeIdentifiers
import RSCore
import Account
import ActivityLog

final class SettingsViewController: UITableViewController {

	private enum Section: Int, CaseIterable {
		case notifications
		case accounts
		case feeds
		case appearance
		case troubleshooting
		case help

		var title: String {
			switch self {
			case .notifications:
				NSLocalizedString("Notifications, Badge, Data, & More", comment: "Notifications, Badge, Data, & More")
			case .accounts:
				NSLocalizedString("Accounts", comment: "Preferences")
			case .feeds:
				NSLocalizedString("Feeds", comment: "Feeds")
			case .appearance:
				NSLocalizedString("Appearance", comment: "Preferences")
			case .troubleshooting:
				NSLocalizedString("Troubleshooting", comment: "Troubleshooting")
			case .help:
				NSLocalizedString("Help", comment: "Help")
			}
		}
	}

	@MainActor fileprivate enum Row {
		case systemSettings
		case account(Account)
		case addAccount
		case importSubscriptions
		case exportSubscriptions
		case addNetNewsWireNewsFeed
		case general
		case sidebar
		case timeline
		case articles
		case errorLog
		case activityLog
		case accountStats
		case dinosaurs
		case cloudKitStats
		case help
		case forum
		case releaseNotes
		case bugTracker
		case about

		var title: String {
			switch self {
			case .systemSettings:
				NSLocalizedString("Open System Settings", comment: "Open System Settings button")
			case .account(let account):
				account.nameForDisplay
			case .addAccount:
				NSLocalizedString("Add Account", comment: "Add Account")
			case .importSubscriptions:
				NSLocalizedString("Import Subscriptions", comment: "Import Subscriptions")
			case .exportSubscriptions:
				NSLocalizedString("Export Subscriptions", comment: "Export Subscriptions")
			case .addNetNewsWireNewsFeed:
				NSLocalizedString("Add NetNewsWire News Feed", comment: "Add NetNewsWire News Feed")
			case .general:
				NSLocalizedString("General", comment: "Preferences")
			case .sidebar:
				NSLocalizedString("Sidebar", comment: "Sidebar")
			case .timeline:
				NSLocalizedString("Timeline", comment: "Timeline")
			case .articles:
				NSLocalizedString("Articles", comment: "Articles")
			case .errorLog:
				NSLocalizedString("Error Log", comment: "Error Log window title")
			case .activityLog:
				NSLocalizedString("Activity Log", comment: "Activity Log screen title")
			case .accountStats:
				NSLocalizedString("Account Stats", comment: "Account Stats screen title")
			case .dinosaurs:
				NSLocalizedString("Dinosaurs", comment: "Dinosaurs")
			case .cloudKitStats:
				NSLocalizedString("iCloud Storage Stats", comment: "iCloud Storage Stats window title")
			case .help:
				NSLocalizedString("NetNewsWire Help", comment: "NetNewsWire Help")
			case .forum:
				NSLocalizedString("NetNewsWire Forum", comment: "NetNewsWire Forum")
			case .releaseNotes:
				NSLocalizedString("Release Notes", comment: "Release Notes")
			case .bugTracker:
				NSLocalizedString("Bug Tracker", comment: "Bug Tracker")
			case .about:
				NSLocalizedString("About NetNewsWire", comment: "About NetNewsWire")
			}
		}

		var iconImage: UIImage {
			switch self {
			case .systemSettings:
				Assets.Images.settingsSystemSettings
			case .account(let account):
				Assets.Images.settingsAccountImage(account.type)
			case .addAccount:
				Assets.Images.plus
			case .importSubscriptions:
				Assets.Images.settingsImportSubscriptions
			case .exportSubscriptions:
				Assets.Images.settingsExportSubscriptions
			case .addNetNewsWireNewsFeed:
				Assets.Images.settingsNetNewsWireNewsFeed
			case .general:
				Assets.Images.preferencesToolbarAppearance
			case .sidebar:
				Assets.Images.settingsSidebar
			case .timeline:
				Assets.Images.settingsTimeline
			case .articles:
				Assets.Images.settingsArticles
			case .errorLog:
				Assets.Images.settingsErrorLog
			case .activityLog:
				Assets.Images.settingsActivityLog
			case .accountStats:
				Assets.Images.settingsAccountStats
			case .dinosaurs:
				Assets.Images.settingsDinosaurs
			case .cloudKitStats:
				Assets.Images.settingsCloudKitStats
			case .help:
				Assets.Images.settingsHelp
			case .forum:
				Assets.Images.settingsForum
			case .releaseNotes:
				Assets.Images.settingsReleaseNotes
			case .bugTracker:
				Assets.Images.settingsBugTracker
			case .about:
				Assets.Images.info
			}
		}

		/// Rows that push another screen get a disclosure indicator.
		var pushesScreen: Bool {
			switch self {
			case .systemSettings, .importSubscriptions, .exportSubscriptions, .addNetNewsWireNewsFeed, .help, .forum, .releaseNotes, .bugTracker:
				false
			case .account, .addAccount, .general, .sidebar, .timeline, .articles, .errorLog, .activityLog, .accountStats, .dinosaurs, .cloudKitStats, .about:
				true
			}
		}
	}

	private static let cellReuseIdentifier = "SettingsCell"

	private weak var opmlAccount: Account?

	/// Pushes the Timeline screen on appearing, so a user can turn off the Mark All as Read confirmation.
	var showTimelineSettings = false
	weak var presentingParentController: UIViewController?

	init() {
		super.init(style: .insetGrouped)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("Settings", comment: "Settings")
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done(_:)))
		doneButton.style = .plain
		navigationItem.rightBarButtonItem = doneButton
		clearsSelectionOnViewWillAppear = false

		NotificationCenter.default.addObserver(self, selector: #selector(handleUserDidAddAccount(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUserDidDeleteAccount(_:)), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleDisplayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)

		tableView.register(VibrantTableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

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

		if showTimelineSettings {
			showTimelineSettings = false
			navigationController?.pushViewController(TimelineSettingsViewController(), animated: true)
		}
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		Section.allCases.count
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		Section(rawValue: section)?.title
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		rowsInSection(section).count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath)
		let row = self.row(at: indexPath)
		cell.textLabel?.text = row.title
		cell.textLabel?.numberOfLines = 0
		cell.textLabel?.adjustsFontForContentSizeCategory = true
		cell.imageView?.image = row.iconImage
		cell.accessoryType = row.pushesScreen ? .disclosureIndicator : .none
		return cell
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let row = self.row(at: indexPath)
		if !row.pushesScreen {
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		}

		switch row {
		case .systemSettings:
			if let url = URL(string: UIApplication.openSettingsURLString) {
				UIApplication.shared.open(url)
			}
		case .account(let account):
			let controller = UIStoryboard.inspector.instantiateController(ofType: AccountInspectorViewController.self)
			controller.account = account
			navigationController?.pushViewController(controller, animated: true)
		case .addAccount:
			let addAccountView = AddAccountView(presentationAnchor: view.window) { [weak self] in
				self?.navigationController?.popViewController(animated: false)
			}
			navigationController?.pushViewController(UIHostingController(rootView: addAccountView), animated: true)
		case .importSubscriptions:
			if let sourceView = tableView.cellForRow(at: indexPath) {
				importOPML(sourceView: sourceView, sourceRect: tableView.rectForRow(at: indexPath))
			}
		case .exportSubscriptions:
			if let sourceView = tableView.cellForRow(at: indexPath) {
				exportOPML(sourceView: sourceView, sourceRect: tableView.rectForRow(at: indexPath))
			}
		case .addNetNewsWireNewsFeed:
			addFeed()
		case .general:
			navigationController?.pushViewController(GeneralSettingsViewController(), animated: true)
		case .sidebar:
			navigationController?.pushViewController(UIHostingController(rootView: SidebarSettingsView()), animated: true)
		case .timeline:
			navigationController?.pushViewController(TimelineSettingsViewController(), animated: true)
		case .articles:
			navigationController?.pushViewController(ArticlesSettingsViewController(), animated: true)
		case .errorLog:
			navigationController?.pushViewController(UIHostingController(rootView: ErrorLogView()), animated: true)
		case .activityLog:
			navigationController?.pushViewController(UIHostingController(rootView: ActivityLogView()), animated: true)
		case .accountStats:
			navigationController?.pushViewController(UIHostingController(rootView: AccountStatsView()), animated: true)
		case .dinosaurs:
			let dinosaursView = DinosaursView(dismissAndPresent: { [weak self] dinosaur in
				guard let self else {
					return
				}
				self.dismiss(animated: true) {
					if let rootSplit = self.presentingParentController as? RootSplitViewController {
						rootSplit.coordinator.discloseFeed(dinosaur.feed, animations: [.scroll, .navigation])
					}
				}
			})
			navigationController?.pushViewController(UIHostingController(rootView: dinosaursView), animated: true)
		case .cloudKitStats:
			navigationController?.pushViewController(UIHostingController(rootView: CloudKitStatsView()), animated: true)
		case .help:
			openURL(HelpURL.helpHome.rawValue)
		case .forum:
			openURL(HelpURL.discourse.rawValue)
		case .releaseNotes:
			openURL(HelpURL.releaseNotes.rawValue)
		case .bugTracker:
			openURL(HelpURL.bugTracker.rawValue)
		case .about:
			navigationController?.pushViewController(UIHostingController(rootView: AboutView()), animated: true)
		}
	}

	// MARK: - Actions

	@objc func done(_ sender: Any) {
		dismiss(animated: true)
	}

	// MARK: - Notifications

	@objc func handleUserDidAddAccount(_ notification: Notification) {
		tableView.reloadData()
	}

	@objc func handleUserDidDeleteAccount(_ notification: Notification) {
		tableView.reloadData()
	}

	@objc func handleDisplayNameDidChange(_ notification: Notification) {
		tableView.reloadData()
	}
}

// MARK: - OPML Document Picker

extension SettingsViewController: UIDocumentPickerDelegate {

	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		for url in urls {
			opmlAccount?.importOPML(url) { result in
				switch result {
				case .success:
					break
				case .failure:
					let title = NSLocalizedString("Import Failed", comment: "Import Failed")
					let message = NSLocalizedString("We were unable to process the selected file.  Please ensure that it is a properly formatted OPML file.", comment: "Import Failed Message")
					self.presentError(title: title, message: message)
				}
			}
		}
	}

}

// MARK: - Private

private extension SettingsViewController {

	func rowsInSection(_ section: Int) -> [Row] {
		switch Section(rawValue: section) {
		case .notifications:
			return [.systemSettings]
		case .accounts:
			return AccountManager.shared.sortedAccounts.map { .account($0) } + [.addAccount]
		case .feeds:
			var rows: [Row] = [.importSubscriptions, .exportSubscriptions]
			if !AccountManager.shared.activeAccounts.isEmpty && !AccountManager.shared.anyAccountHasNetNewsWireNewsSubscription() {
				rows.append(.addNetNewsWireNewsFeed)
			}
			return rows
		case .appearance:
			return [.general, .sidebar, .timeline, .articles]
		case .troubleshooting:
			var rows: [Row] = [.errorLog, .activityLog, .accountStats, .dinosaurs]
			if AccountManager.shared.hasiCloudAccount {
				rows.append(.cloudKitStats)
			}
			return rows
		case .help:
			return [.help, .forum, .releaseNotes, .bugTracker, .about]
		case nil:
			return []
		}
	}

	func row(at indexPath: IndexPath) -> Row {
		rowsInSection(indexPath.section)[indexPath.row]
	}

	func addFeed() {
		self.dismiss(animated: true)

		let addFeedView = AddFeedView(initialFeed: AccountManager.netNewsWireNewsURL, initialFeedName: NSLocalizedString("NetNewsWire News", comment: "NetNewsWire News"))
		let hostingController = UIHostingController(rootView: addFeedView)
		hostingController.modalPresentationStyle = .formSheet
		hostingController.preferredContentSize = UIViewController.formSheetSize

		presentingParentController?.present(hostingController, animated: true)
	}

	func importOPML(sourceView: UIView, sourceRect: CGRect) {
		switch AccountManager.shared.activeAccounts.count {
		case 0:
			presentError(title: "Error", message: NSLocalizedString("You must have at least one active account.", comment: "Missing active account"))
		case 1:
			opmlAccount = AccountManager.shared.activeAccounts.first
			importOPMLDocumentPicker()
		default:
			importOPMLAccountPicker(sourceView: sourceView, sourceRect: sourceRect)
		}
	}

	func importOPMLAccountPicker(sourceView: UIView, sourceRect: CGRect) {
		let title = NSLocalizedString("Choose an account to receive the imported feeds and folders", comment: "Import Account")
		let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

		if let popoverController = alert.popoverPresentationController {
			popoverController.sourceView = view
			popoverController.sourceRect = sourceRect
		}

		for account in AccountManager.shared.sortedActiveAccounts {
			let action = UIAlertAction(title: account.nameForDisplay, style: .default) { [weak self] _ in
				self?.opmlAccount = account
				self?.importOPMLDocumentPicker()
			}
			alert.addAction(action)
		}

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel button")
		alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

		self.present(alert, animated: true)
	}

	func importOPMLDocumentPicker() {
		var contentTypes: [UTType] = []

		// Create UTType for .opml files by extension, without requiring conformance.
		// This ensures files ending in .opml can be selected no matter how OPML is registered.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/4858>
		if let opmlByExtension = UTType(filenameExtension: "opml") {
			contentTypes.append(opmlByExtension)
		}

		// Also try the registered org.opml.opml UTI if it exists
		if let registeredOPML = UTType("org.opml.opml") {
			contentTypes.append(registeredOPML)
		}

		// Include XML as a fallback
		contentTypes.append(.xml)

		let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
		documentPicker.delegate = self
		documentPicker.modalPresentationStyle = .formSheet
		self.present(documentPicker, animated: true)
	}

	func exportOPML(sourceView: UIView, sourceRect: CGRect) {
		if AccountManager.shared.accounts.count == 1 {
			opmlAccount = AccountManager.shared.accounts.first!
			exportOPMLDocumentPicker()
		} else {
			exportOPMLAccountPicker(sourceView: sourceView, sourceRect: sourceRect)
		}
	}

	func exportOPMLAccountPicker(sourceView: UIView, sourceRect: CGRect) {
		let title = NSLocalizedString("Choose an account with the subscriptions to export", comment: "Export Account")
		let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

		if let popoverController = alert.popoverPresentationController {
			popoverController.sourceView = view
			popoverController.sourceRect = sourceRect
		}

		for account in AccountManager.shared.sortedAccounts {
			let action = UIAlertAction(title: account.nameForDisplay, style: .default) { [weak self] _ in
				self?.opmlAccount = account
				self?.exportOPMLDocumentPicker()
			}
			alert.addAction(action)
		}

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel button")
		alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

		self.present(alert, animated: true)
	}

	func exportOPMLDocumentPicker() {
		guard let account = opmlAccount else { return }

		let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
		let filename = "Subscriptions-\(accountName).opml"
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		do {
			try account.logActivity(kind: .exportOPML, detail: filename) {
				let opmlString = OPMLExporter.OPMLString(with: account, title: filename)
				try opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
			}
		} catch {
			self.presentError(title: "OPML Export Error", message: error.localizedDescription)
		}

		let docPicker = UIDocumentPickerViewController(forExporting: [tempFile])
		docPicker.modalPresentationStyle = .formSheet
		self.present(docPicker, animated: true)
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
