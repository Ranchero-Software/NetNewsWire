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
	
	weak var presentingParentController: UIViewController?
	
	override func viewDidLoad() {
		// This hack mostly works around a bug in static tables with dynamic type.  See: https://spin.atomicobject.com/2018/10/15/dynamic-type-static-uitableview/
		NotificationCenter.default.removeObserver(tableView!, name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if AppDefaults.timelineSortDirection == .orderedAscending {
			timelineSortOrderSwitch.isOn = true
		} else {
			timelineSortOrderSwitch.isOn = false
		}

		refreshIntervalLabel.text = AppDefaults.refreshInterval.description()
		
		let buildLabel = UILabel(frame: CGRect(x: 20.0, y: 0.0, width: 0.0, height: 0.0))
		buildLabel.font = UIFont.systemFont(ofSize: 11.0)
		buildLabel.textColor = UIColor.gray
		buildLabel.text = "\(Bundle.main.appName) v \(Bundle.main.versionNumber) (Build \(Bundle.main.buildNumber))"
		buildLabel.sizeToFit()
		buildLabel.translatesAutoresizingMaskIntoConstraints = false
		tableView.tableFooterView = buildLabel

	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		switch indexPath.section {
		case 0:
			print("Accounts isn't ready yet")
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
			default:
				UIApplication.shared.open(URL(string: "https://github.com/brentsimmons/NetNewsWire/tree/master/Technotes")!, options: [:])
			}
		case 2:
			UIApplication.shared.open(URL(string: "https://appcamp4girls.com/contribute/")!, options: [:])
		default:
			switch indexPath.row {
			case 0:
				let timeline = UIStoryboard.settings.instantiateController(ofType: RefreshIntervalViewController.self)
				self.navigationController?.pushViewController(timeline, animated: true)
			case 1:
				addFeed()
			case 2:
				importOPML()
			case 3:
				exportOPML()
			default:
				print("export")
			}
		}
		
	}

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
			do {
				try OPMLImporter.parseAndImport(fileURL: url, account: AccountManager.shared.localAccount)
			} catch {
				presentError(title: "OPML Import Error", message: error.localizedDescription)
			}
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
		let opmlString = OPMLExporter.OPMLString(with: AccountManager.shared.localAccount, title: filename)
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
