//
//  SettingsViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class SettingsViewController: UITableViewController {

	@IBOutlet weak var refreshIntervalLabel: UILabel!
	@IBOutlet weak var timelineSortOrderSwitch: UISwitch!
	@IBOutlet weak var timelineNumberOfLinesLabel: UILabel!
	
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

		refreshIntervalLabel.text = AppDefaults.refreshInterval.description()
		
		let numberOfLinesText = NSLocalizedString(" lines", comment: "Lines")
		timelineNumberOfLinesLabel.text = "\(AppDefaults.timelineNumberOfLines)" + numberOfLinesText
		
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
		case 0:
			return AccountManager.shared.accounts.count + 1
		case 1:
			let defaultNumberOfRows = super.tableView(tableView, numberOfRowsInSection: section)
			if AccountManager.shared.activeAccounts.isEmpty {
				// Hide the add NetNewsWire feed row if they don't have any active accounts
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
		case 0:
			
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
		
		let bgView = UIView()
		bgView.backgroundColor = AppAssets.netNewsWireBlueColor
		cell.selectedBackgroundView = bgView
		return cell
		
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		switch indexPath.section {
		case 0:
			let sortedAccounts = AccountManager.shared.sortedAccounts
			if indexPath.row == sortedAccounts.count {
				let controller = UIStoryboard.settings.instantiateController(ofType: AddAccountViewController.self)
				self.navigationController?.pushViewController(controller, animated: true)
			} else {
				let controller = UIStoryboard.settings.instantiateController(ofType: DetailAccountViewController.self)
				controller.account = sortedAccounts[indexPath.row]
				self.navigationController?.pushViewController(controller, animated: true)
			}
		case 1:
			switch indexPath.row {
			case 0:
				let timeline = UIStoryboard.settings.instantiateController(ofType: AboutViewController.self)
				self.navigationController?.pushViewController(timeline, animated: true)
			case 1:
				UIApplication.shared.open(URL(string: "https://ranchero.com/netnewswire/")!, options: [:])
			case 2:
				UIApplication.shared.open(URL(string: "https://github.com/brentsimmons/NetNewsWire")!, options: [:])
			case 3:
				UIApplication.shared.open(URL(string: "https://github.com/brentsimmons/NetNewsWire/issues")!, options: [:])
			case 4:
				UIApplication.shared.open(URL(string: "https://github.com/brentsimmons/NetNewsWire/tree/master/Technotes")!, options: [:])
			case 5:
				addFeed()
			default:
				UIApplication.shared.open(URL(string: "https://ranchero.com/netnewswire/")!, options: [:])
			}
		case 2:
			if indexPath.row == 1 {
				let timeline = UIStoryboard.settings.instantiateController(ofType: TimelineNumberOfLinesViewController.self)
				self.navigationController?.pushViewController(timeline, animated: true)
			}
		case 3:
			switch indexPath.row {
			case 0:
				let timeline = UIStoryboard.settings.instantiateController(ofType: RefreshIntervalViewController.self)
				self.navigationController?.pushViewController(timeline, animated: true)
			case 1:
				importOPML()
			case 2:
				exportOPML()
			default:
				print("export")
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
		if indexPath.section == 0 {
			return super.tableView(tableView, heightForRowAt: IndexPath(row: 0, section: 0))
		} else {
			return super.tableView(tableView, heightForRowAt: indexPath)
		}
	}
	
	override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
		if indexPath.section == 0 {
			return super.tableView(tableView, indentationLevelForRowAt: IndexPath(row: 0, section: 0))
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
	
	@objc func contentSizeCategoryDidChange() {
		tableView.reloadData()
	}
	
}

// MARK: OPML Document Picker

extension SettingsViewController: UIDocumentPickerDelegate {
	
	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		
		for url in urls {
			AccountManager.shared.defaultAccount.importOPML(url) { result in}
		}
		
	}
	
}

// MARK: Private

private extension SettingsViewController {
	
	func addFeed() {
		
		let appNewsURLString = "https://nnw.ranchero.com/feed.json"
		if AccountManager.shared.anyAccountHasFeedWithURL(appNewsURLString) {
			presentError(title: "Subscribe", message: "You are already subscribed to the NetNewsWire news feed.")
			return
		}
		
		self.dismiss(animated: true)
		
		let addNavViewController = UIStoryboard.add.instantiateInitialViewController() as! UINavigationController
		let addViewController = addNavViewController.topViewController as! AddContainerViewController
		addNavViewController.modalPresentationStyle = .formSheet
		addNavViewController.preferredContentSize = AddContainerViewController.preferredContentSizeForFormSheetDisplay
		addViewController.initialFeed = appNewsURLString
		addViewController.initialFeedName = "NetNewsWire News"
		
		presentingParentController?.present(addNavViewController, animated: true)
		
	}
	
	func importOPML() {
		
		let docPicker = UIDocumentPickerViewController(documentTypes: ["public.xml", "org.opml.opml"], in: .import)
		docPicker.delegate = self
		docPicker.modalPresentationStyle = .formSheet
		self.present(docPicker, animated: true)
		
	}
	
	func exportOPML() {
		
		let filename = "MySubscriptions.opml"
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
		let opmlString = OPMLExporter.OPMLString(with: AccountManager.shared.defaultAccount, title: filename)
		do {
			try opmlString.write(to: tempFile, atomically: true, encoding: String.Encoding.utf8)
		} catch {
			self.presentError(title: "OPML Export Error", message: error.localizedDescription)
		}
		
		let docPicker = UIDocumentPickerViewController(url: tempFile, in: .exportToService)
		docPicker.modalPresentationStyle = .formSheet
		self.present(docPicker, animated: true)
		
	}
	
}
