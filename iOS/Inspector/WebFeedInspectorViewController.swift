//
//  WebFeedInspectorViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/6/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class WebFeedInspectorViewController: UITableViewController {
	
	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 500.0)
	
	var webFeed: WebFeed!
	@IBOutlet weak var nameTextField: UITextField!
	@IBOutlet weak var notifyAboutNewArticlesSwitch: UISwitch!
	@IBOutlet weak var alwaysShowReaderViewSwitch: UISwitch!
	@IBOutlet weak var homePageLabel: InteractiveLabel!
	@IBOutlet weak var feedURLLabel: InteractiveLabel!
	
	private var headerView: InspectorIconHeaderView?
	private var iconImage: IconImage {
		if let feedIcon = appDelegate.webFeedIconDownloader.icon(for: webFeed) {
			return feedIcon
		}
		if let favicon = appDelegate.faviconDownloader.favicon(for: webFeed) {
			return favicon
		}
		return FaviconGenerator.favicon(webFeed)
	}
	
	override func viewDidLoad() {
		tableView.register(InspectorIconHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		
		navigationItem.title = webFeed.nameForDisplay
		nameTextField.text = webFeed.nameForDisplay
		
		notifyAboutNewArticlesSwitch.setOn(webFeed.isNotifyAboutNewArticles ?? false, animated: false)
		alwaysShowReaderViewSwitch.setOn(webFeed.isArticleExtractorAlwaysOn ?? false, animated: false)

		homePageLabel.text = webFeed.homePageURL
		feedURLLabel.text = webFeed.url
		
		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		if nameTextField.text != webFeed.nameForDisplay {
			let nameText = nameTextField.text ?? ""
			let newName = nameText.isEmpty ? (webFeed.name ?? NSLocalizedString("Untitled", comment: "Feed name")) : nameText
			webFeed.rename(to: newName) { _ in }
		}
	}
	
	// MARK: Notifications
	@objc func webFeedIconDidBecomeAvailable(_ notification: Notification) {
		headerView?.iconView.iconImage = iconImage
	}
	
	@IBAction func notifyAboutNewArticlesChanged(_ sender: Any) {
		webFeed.isNotifyAboutNewArticles = notifyAboutNewArticlesSwitch.isOn
	}
	
	@IBAction func alwaysShowReaderViewChanged(_ sender: Any) {
		webFeed.isArticleExtractorAlwaysOn = alwaysShowReaderViewSwitch.isOn
	}
	
	@IBAction func done(_ sender: Any) {
		dismiss(animated: true)
	}
	
}

// MARK: Table View

extension WebFeedInspectorViewController {
	
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : super.tableView(tableView, heightForHeaderInSection: section)
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as? InspectorIconHeaderView
			headerView?.iconView.iconImage = iconImage
			return headerView
		} else {
			return super.tableView(tableView, viewForHeaderInSection: section)
		}
	}
	
}

// MARK: UITextFieldDelegate

extension WebFeedInspectorViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}
