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

class SettingsViewController: UITableViewController {

	private let appNewsURLString = "https://nnw.ranchero.com/feed.json"
	private weak var opmlAccount: Account?
	
	@IBOutlet weak var timelineSortOrderSwitch: UISwitch!
	@IBOutlet weak var groupByFeedSwitch: UISwitch!
	@IBOutlet weak var refreshClearsReadArticlesSwitch: UISwitch!
	@IBOutlet weak var confirmMarkAllAsReadSwitch: UISwitch!
	@IBOutlet weak var showFullscreenArticlesSwitch: UISwitch!
	@IBOutlet weak var colorPaletteDetailLabel: UILabel!
	
	var scrollToArticlesSection = false
	weak var presentingParentController: UIViewController?
	
	override func viewDidLoad() {
		// This hack mostly works around a bug in static tables with dynamic type.  See: https://spin.atomicobject.com/2018/10/15/dynamic-type-static-uitableview/
		NotificationCenter.default.removeObserver(tableView!, name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange), name: .DisplayNameDidChange, object: nil)

		tableView.register(UINib(nibName: "SettingsAccountTableViewCell", bundle: nil), forCellReuseIdentifier: "SettingsAccountTableViewCell")
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
			if AccountManager.shared.activeAccounts.isEmpty || AccountManager.shared.anyAccountHasFeedWithURL(appNewsURLString) {
				return defaultNumberOfRows - 1
			}
			return defaultNumberOfRows
		case 4:
			return traitCollection.userInterfaceIdiom == .phone ? 2 : 1
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
				let acctCell = tableView.dequeueReusableCell(withIdentifier: "SettingsAccountTableViewCell", for: indexPath) as! SettingsAccountTableViewCell
				acctCell.applyThemeProperties()
				let account = sortedAccounts[indexPath.row]
				acctCell.accountImage?.image = AppAssets.image(for: account.type)
				acctCell.accountNameLabel?.text = account.nameForDisplay
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
		case 5:
			let colorPalette = UIStoryboard.settings.instantiateController(ofType: ColorPaletteTableViewController.self)
			self.navigationController?.pushViewController(colorPalette, animated: true)
		case 6:
			switch indexPath.row {
			case 0:
				openURL("https://ranchero.com/netnewswire/help/ios/5.0/en/")
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 1:
				openURL("https://ranchero.com/netnewswire/")
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 2:
				openURL("https://github.com/brentsimmons/NetNewsWire/blob/master/Technotes/HowToSupportNetNewsWire.markdown")
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 3:
				openURL("https://github.com/brentsimmons/NetNewsWire")
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 4:
				openURL("https://github.com/brentsimmons/NetNewsWire/issues")
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 5:
				openURL("https://github.com/brentsimmons/NetNewsWire/tree/master/Technotes")
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 6:
				openURL("https://ranchero.com/netnewswire/slack")
				tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
			case 7:
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
		return super.tableView(tableView, indentationLevelForRowAt: IndexPath(row: 0, section: 1))
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
		
		let addNavViewController = UIStoryboard.add.instantiateInitialViewController() as! UINavigationController
		let addViewController = addNavViewController.topViewController as! AddContainerViewController
		addNavViewController.modalPresentationStyle = .formSheet
		addNavViewController.preferredContentSize = AddContainerViewController.preferredContentSizeForFormSheetDisplay
		addViewController.initialControllerType = .feed
		addViewController.initialFeed = appNewsURLString
		addViewController.initialFeedName = "NetNewsWire News"
		
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
			let action = UIAlertAction(title: account.nameForDisplay, style: .default) { [weak self] action in
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
		
		let utiArray = UTTypeCreateAllIdentifiersForTag(kUTTagClassFilenameExtension, "opml" as NSString, nil)?.takeRetainedValue() as? [String] ?? [String]()

		var opmlUTIs = utiArray
			.compactMap({ UTTypeCopyDeclaration($0 as NSString)?.takeUnretainedValue() as? [String: Any] })
			.reduce([String]()) { (result, dict) in
				return result + dict.values.compactMap({ $0 as? String })
			}
		opmlUTIs.append("public.xml")
		
		let docPicker = UIDocumentPickerViewController(documentTypes: opmlUTIs, in: .import)
		docPicker.delegate = self
		docPicker.modalPresentationStyle = .formSheet
		self.present(docPicker, animated: true)
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
			let action = UIAlertAction(title: account.nameForDisplay, style: .default) { [weak self] action in
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
		
		let docPicker = UIDocumentPickerViewController(url: tempFile, in: .exportToService)
		docPicker.modalPresentationStyle = .formSheet
		self.present(docPicker, animated: true)
	}
	
	func openURL(_ urlString: String) {
		let vc = SFSafariViewController(url: URL(string: urlString)!)
		vc.modalPresentationStyle = .pageSheet
		present(vc, animated: true)
	}
	
}
