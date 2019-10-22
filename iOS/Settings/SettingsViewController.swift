//
//  SettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import SafariServices

class SettingsViewController: UITableViewController {

	private let appNewsURLString = "https://nnw.ranchero.com/feed.json"
	private weak var opmlAccount: Account?
	
	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 400.0)
	
	@IBOutlet weak var refreshIntervalLabel: UILabel!
	@IBOutlet weak var timelineSortOrderSwitch: UISwitch!
	@IBOutlet weak var groupByFeedSwitch: UISwitch!
	@IBOutlet weak var numberOfTextLinesLabel: UILabel!
	@IBOutlet weak var numberOfTextLinesSteppper: UIStepper!
	
	weak var presentingParentController: UIViewController?
	
	override func viewDidLoad() {
		// This hack mostly works around a bug in static tables with dynamic type.  See: https://spin.atomicobject.com/2018/10/15/dynamic-type-static-uitableview/
		NotificationCenter.default.removeObserver(tableView!, name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
		
		tableView.register(UINib(nibName: "SettingsTableViewCell", bundle: nil), forCellReuseIdentifier: "SettingsTableViewCell")
		
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

		refreshIntervalLabel.text = AppDefaults.refreshInterval.description()
		
		let numberOfTextLines = AppDefaults.timelineNumberOfLines
		numberOfTextLinesSteppper.value = Double(numberOfTextLines)
		updateNumberOfTextLinesLabel(value: numberOfTextLines)
		
		let buildLabel = NonIntrinsicLabel(frame: CGRect(x: 20.0, y: 0.0, width: 0.0, height: 0.0))
		buildLabel.font = UIFont.systemFont(ofSize: 11.0)
		buildLabel.textColor = UIColor.gray
		buildLabel.text = "\(Bundle.main.appName) v \(Bundle.main.versionNumber) (Build \(Bundle.main.buildNumber))"
		buildLabel.sizeToFit()
		buildLabel.translatesAutoresizingMaskIntoConstraints = false
		tableView.tableFooterView = buildLabel

		tableView.reloadData()
		
	}
	
	// MARK: UITableView
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 1:
			return AccountManager.shared.accounts.count + 1
		case 4:
			let defaultNumberOfRows = super.tableView(tableView, numberOfRowsInSection: section)
			if AccountManager.shared.activeAccounts.isEmpty || AccountManager.shared.anyAccountHasFeedWithURL(appNewsURLString) {
				return defaultNumberOfRows - 1
			}
			return defaultNumberOfRows
		default:
			return super.tableView(tableView, numberOfRowsInSection: section)
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell: UITableViewCell
		switch indexPath.section {
		case 1:
			
			cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCell", for: indexPath)
			cell.textLabel?.adjustsFontForContentSizeCategory = true
			
			let sortedAccounts = AccountManager.shared.sortedAccounts
			if indexPath.row == sortedAccounts.count {
				cell.textLabel?.text = NSLocalizedString("Add Account", comment: "Accounts")
			} else {
				cell.textLabel?.text = sortedAccounts[indexPath.row].nameForDisplay
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
		case 1:
			let sortedAccounts = AccountManager.shared.sortedAccounts
			if indexPath.row == sortedAccounts.count {
				let controller = UIStoryboard.settings.instantiateController(ofType: AddAccountViewController.self)
				self.navigationController?.pushViewController(controller, animated: true)
			} else {
				let controller = UIStoryboard.settings.instantiateController(ofType: DetailAccountViewController.self)
				controller.account = sortedAccounts[indexPath.row]
				self.navigationController?.pushViewController(controller, animated: true)
			}
		case 3:
			switch indexPath.row {
			case 0:
				let timeline = UIStoryboard.settings.instantiateController(ofType: RefreshIntervalViewController.self)
				self.navigationController?.pushViewController(timeline, animated: true)
			case 1:
				if let sourceView = tableView.cellForRow(at: indexPath) {
					let sourceRect = tableView.rectForRow(at: indexPath)
					importOPML(sourceView: sourceView, sourceRect: sourceRect)
				}
			case 2:
				if let sourceView = tableView.cellForRow(at: indexPath) {
					let sourceRect = tableView.rectForRow(at: indexPath)
					exportOPML(sourceView: sourceView, sourceRect: sourceRect)
				}
			default:
				break
			}
		case 4:
			switch indexPath.row {
			case 0:
				let timeline = UIStoryboard.settings.instantiateController(ofType: AboutViewController.self)
				self.navigationController?.pushViewController(timeline, animated: true)
			case 1:
				openURL("https://ranchero.com/netnewswire/")
			case 2:
				openURL("https://github.com/brentsimmons/NetNewsWire/blob/master/Technotes/HowToSupportNetNewsWire.markdown")
			case 3:
				openURL("https://github.com/brentsimmons/NetNewsWire")
			case 4:
				openURL("https://github.com/brentsimmons/NetNewsWire/issues")
			case 5:
				openURL("https://github.com/brentsimmons/NetNewsWire/tree/master/Technotes")
			case 6:
				addFeed()
			default:
				break
			}
		default:
			break
		}
		
		tableView.selectRow(at: nil, animated: true, scrollPosition: .none)
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
		if indexPath.section == 1 {
			return super.tableView(tableView, heightForRowAt: IndexPath(row: 0, section: 1))
		} else {
			return super.tableView(tableView, heightForRowAt: indexPath)
		}
	}
	
	override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
		if indexPath.section == 1 {
			return super.tableView(tableView, indentationLevelForRowAt: IndexPath(row: 0, section: 1))
		} else {
			return super.tableView(tableView, indentationLevelForRowAt: indexPath)
		}
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
	
	@IBAction func stepNumberOfTextLines(_ sender: UIStepper) {
		let numberOfLines = Int(sender.value)
		AppDefaults.timelineNumberOfLines = numberOfLines
		updateNumberOfTextLinesLabel(value: numberOfLines)
	}
	
	@objc func contentSizeCategoryDidChange() {
		tableView.reloadData()
	}
	
}

// MARK: OPML Document Picker

extension SettingsViewController: UIDocumentPickerDelegate {
	
	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		for url in urls {
			opmlAccount?.importOPML(url) { result in}
		}
	}
	
}

// MARK: Private

private extension SettingsViewController {
	
	func updateNumberOfTextLinesLabel(value: Int) {
		let localizedText = NSLocalizedString("Number of Text Lines: %d", comment: "Number of Text Lines")
		numberOfTextLinesLabel.text = NSString.localizedStringWithFormat(localizedText as NSString, value) as String
	}
	
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
		let title = NSLocalizedString("Select an Import Account", comment: "Select an Import Account")
		let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
		
		if let popoverController = alert.popoverPresentationController {
			popoverController.sourceView = view
			popoverController.sourceRect = sourceRect
		}

		for account in AccountManager.shared.activeAccounts {
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
		let docPicker = UIDocumentPickerViewController(documentTypes: ["public.xml", "org.opml.opml"], in: .import)
		docPicker.delegate = self
		docPicker.modalPresentationStyle = .formSheet
		self.present(docPicker, animated: true)
	}
	
	func exportOPML(sourceView: UIView, sourceRect: CGRect) {
		if AccountManager.shared.accounts.count == 1 {
			exportOPMLDocumentPicker()
		} else {
			exportOPMLAccountPicker(sourceView: sourceView, sourceRect: sourceRect)
		}
	}
	
	func exportOPMLAccountPicker(sourceView: UIView, sourceRect: CGRect) {
		let title = NSLocalizedString("Select an Export Account", comment: "Select an Export Account")
		let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
		
		if let popoverController = alert.popoverPresentationController {
			popoverController.sourceView = view
			popoverController.sourceRect = sourceRect
		}

		for account in AccountManager.shared.accounts {
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
