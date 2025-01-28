//
//  SettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import CoreServices
import SafariServices
import SwiftUI
import UniformTypeIdentifiers

// swiftlint:disable:next type_body_length
final class SettingsViewController: UITableViewController {

	private weak var opmlAccount: Account?

	@IBOutlet weak var timelineSortOrderSwitch: UISwitch!
	@IBOutlet weak var groupByFeedSwitch: UISwitch!
	@IBOutlet weak var refreshClearsReadArticlesSwitch: UISwitch!
	@IBOutlet weak var articleThemeDetailLabel: UILabel!
	@IBOutlet weak var confirmMarkAllAsReadSwitch: UISwitch!
	@IBOutlet weak var showFullscreenArticlesSwitch: UISwitch!
	@IBOutlet weak var colorPaletteDetailLabel: UILabel!
	@IBOutlet weak var openLinksInNetNewsWire: UISwitch!

	var scrollToArticlesSection = false
	weak var presentingParentController: UIViewController?

	override func viewDidLoad() {
		// This hack mostly works around a bug in static tables with dynamic type.  See: https://spin.atomicobject.com/2018/10/15/dynamic-type-static-uitableview/
		NotificationCenter.default.removeObserver(tableView!, name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange), name: .DisplayNameDidChange, object: nil)

		tableView.register(UINib(nibName: "SettingsComboTableViewCell", bundle: nil), forCellReuseIdentifier: "SettingsComboTableViewCell")
		tableView.register(UINib(nibName: "SettingsTableViewCell", bundle: nil), forCellReuseIdentifier: "SettingsTableViewCell")

		tableView.rowHeight = UITableView.automaticDimension
		tableView.estimatedRowHeight = 44
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if AppDefaults.timelineSortDirection == .orderedAscending {
			timelineSortOrderSwitch.isOn = true
		} else {
			timelineSortOrderSwitch.isOn = false
		}

		groupByFeedSwitch.isOn = AppDefaults.timelineGroupByFeed
		refreshClearsReadArticlesSwitch.isOn = AppDefaults.refreshClearsReadArticles
		confirmMarkAllAsReadSwitch.isOn = AppDefaults.confirmMarkAllAsRead
		showFullscreenArticlesSwitch.isOn = AppDefaults.articleFullscreenAvailable
		openLinksInNetNewsWire.isOn = !AppDefaults.useSystemBrowser

		articleThemeDetailLabel.text = ArticleThemesManager.shared.currentTheme.name
		colorPaletteDetailLabel.text = String(describing: AppDefaults.userInterfaceColorPalette)

		let buildLabel = NonIntrinsicLabel(frame: CGRect(x: 32.0, y: 0.0, width: 0.0, height: 0.0))
		buildLabel.font = UIFont.systemFont(ofSize: 11.0)
		buildLabel.textColor = UIColor.gray
		buildLabel.text = "\(Bundle.main.appName) \(Bundle.main.versionNumber) (Build \(Bundle.main.buildNumber))"
		buildLabel.sizeToFit()
		buildLabel.translatesAutoresizingMaskIntoConstraints = false

		let wrapperView = UIView(frame: CGRect(x: 0, y: 0, width: buildLabel.frame.width, height: buildLabel.frame.height + 10.0))
		wrapperView.translatesAutoresizingMaskIntoConstraints = false
		wrapperView.addSubview(buildLabel)
		tableView.tableFooterView = wrapperView
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		self.tableView.selectRow(at: nil, animated: true, scrollPosition: .none)

		if scrollToArticlesSection {
			tableView.scrollToRow(at: IndexPath(row: 0, section: 4), at: .top, animated: true)
			scrollToArticlesSection = false
		}
	}

	// MARK: UITableView

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

		switch section {
		case 1:
			return AccountManager.shared.accounts.count + 1
		case 2:
			let defaultNumberOfRows = super.tableView(tableView, numberOfRowsInSection: section)
			if AccountManager.shared.activeAccounts.isEmpty || AccountManager.shared.anyAccountHasNetNewsWireNewsSubscription() {
				return defaultNumberOfRows - 1
			}
			return defaultNumberOfRows
		case 4:
			return traitCollection.userInterfaceIdiom == .phone ? 4 : 3
		default:
			return super.tableView(tableView, numberOfRowsInSection: section)
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

		let cell: UITableViewCell
		switch indexPath.section {
		case 1:

			let sortedAccounts = AccountManager.shared.sortedAccounts
			if indexPath.row == sortedAccounts.count {
				cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCell", for: indexPath)
				cell.textLabel?.text = NSLocalizedString("Add Account", comment: "Accounts")
			} else {
				let acctCell = tableView.dequeueReusableCell(withIdentifier: "SettingsComboTableViewCell", for: indexPath) as! SettingsComboTableViewCell
				acctCell.applyThemeProperties()
				let account = sortedAccounts[indexPath.row]
				acctCell.comboImage?.image = AppImage.account(account.type)
				acctCell.comboNameLabel?.text = account.nameForDisplay
				cell = acctCell
			}
		default:
			cell = super.tableView(tableView, cellForRowAt: indexPath)
		}

		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

		switch indexPath.section {
		case 0:
			UIApplication.shared.open(URL(string: "\(UIApplication.openSettingsURLString)")!)
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		case 1:
			let sortedAccounts = AccountManager.shared.sortedAccounts
			if indexPath.row == sortedAccounts.count {
				let controller = UIStoryboard.settings.instantiateController(ofType: AddAccountViewController.self)
				self.navigationController?.pushViewController(controller, animated: true)
			} else {
				let controller = UIStoryboard.inspector.instantiateController(ofType: AccountInspectorViewController.self)
				controller.account = sortedAccounts[indexPath.row]
				self.navigationController?.pushViewController(controller, animated: true)
			}
		case 2:
			switch indexPath.row {
			case 0:
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
				if let sourceView = tableView.cellForRow(at: indexPath) {
					let sourceRect = tableView.rectForRow(at: indexPath)
					importOPML(sourceView: sourceView, sourceRect: sourceRect)
				}
			case 1:
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
				if let sourceView = tableView.cellForRow(at: indexPath) {
					let sourceRect = tableView.rectForRow(at: indexPath)
					exportOPML(sourceView: sourceView, sourceRect: sourceRect)
				}
			case 2:
				addFeed()
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			default:
				break
			}
		case 3:
			switch indexPath.row {
			case 3:
				let timeline = UIStoryboard.settings.instantiateController(ofType: TimelineCustomizerViewController.self)
				self.navigationController?.pushViewController(timeline, animated: true)
			default:
				break
			}
		case 4:
			switch indexPath.row {
			case 0:
				let articleThemes = UIStoryboard.settings.instantiateController(ofType: ArticleThemesTableViewController.self)
				self.navigationController?.pushViewController(articleThemes, animated: true)
			default:
				break
			}
		case 5:
			let colorPalette = UIStoryboard.settings.instantiateController(ofType: ColorPaletteTableViewController.self)
			self.navigationController?.pushViewController(colorPalette, animated: true)
		case 6:
			switch indexPath.row {
			case 0:
				openURL("https://netnewswire.com/help/ios/6.1/en/")
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 1:
				openURL(URL.releaseNotes.absoluteString)
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 2:
				openURL("https://github.com/brentsimmons/NetNewsWire/issues")
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 3:
				let timeline = UIStoryboard.settings.instantiateController(ofType: AboutViewController.self)
				self.navigationController?.pushViewController(timeline, animated: true)
			default:
				break
			}
		default:
			tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
		}
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		false
	}

	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		false
	}

	override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
		.none
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		UITableView.automaticDimension
	}

	override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
		super.tableView(tableView, indentationLevelForRowAt: IndexPath(row: 0, section: 1))
	}

	// MARK: Actions

	@IBAction func done(_ sender: Any) {
		dismiss(animated: true)
	}

	@IBAction func switchTimelineOrder(_ sender: Any) {
		AppDefaults.timelineSortDirection = timelineSortOrderSwitch.isOn ? .orderedAscending : .orderedDescending
	}

	@IBAction func switchGroupByFeed(_ sender: Any) {
		AppDefaults.timelineGroupByFeed = groupByFeedSwitch.isOn
	}

	@IBAction func switchClearsReadArticles(_ sender: Any) {
		AppDefaults.refreshClearsReadArticles = refreshClearsReadArticlesSwitch.isOn
	}

	@IBAction func switchConfirmMarkAllAsRead(_ sender: Any) {
		AppDefaults.confirmMarkAllAsRead = confirmMarkAllAsReadSwitch.isOn
	}

	@IBAction func switchFullscreenArticles(_ sender: Any) {
		AppDefaults.articleFullscreenAvailable = showFullscreenArticlesSwitch.isOn
	}

	@IBAction func switchBrowserPreference(_ sender: Any) {
		AppDefaults.useSystemBrowser = !openLinksInNetNewsWire.isOn
	}

	// MARK: Notifications

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
}

// MARK: OPML Document Picker

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

// MARK: Private

private extension SettingsViewController {

	func addFeed() {
		self.dismiss(animated: true)

		let addNavViewController = UIStoryboard.add.instantiateViewController(withIdentifier: "AddFeedViewControllerNav") as! UINavigationController
		let addViewController = addNavViewController.topViewController as! AddFeedViewController
		addViewController.initialFeed = AccountManager.netNewsWireNewsURL
		addViewController.initialFeedName = NSLocalizedString("NetNewsWire News", comment: "NetNewsWire News")
		addNavViewController.modalPresentationStyle = .formSheet
		addNavViewController.preferredContentSize = AddFeedViewController.preferredContentSizeForFormSheetDisplay

		presentingParentController?.present(addNavViewController, animated: true)
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

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

		self.present(alert, animated: true)
	}

	func importOPMLDocumentPicker() {

		let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.opml, UTType.xml], asCopy: true)
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

		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

		self.present(alert, animated: true)
	}

	func exportOPMLDocumentPicker() {
		guard let account = opmlAccount else { return }

		let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
		let filename = "Subscriptions-\(accountName).opml"
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		let opmlString = OPMLExporter.OPMLString(with: account, title: filename)
		do {
			try opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
		} catch {
			self.presentError(title: "OPML Export Error", message: error.localizedDescription)
		}

		let documentPicker = UIDocumentPickerViewController(forExporting: [tempFile])
		documentPicker.modalPresentationStyle = .formSheet
		self.present(documentPicker, animated: true)
	}

	func openURL(_ urlString: String) {
		let vc = SFSafariViewController(url: URL(string: urlString)!)
		vc.modalPresentationStyle = .pageSheet
		present(vc, animated: true)
	}
}
