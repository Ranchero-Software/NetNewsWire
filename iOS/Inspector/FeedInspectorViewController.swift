//
//  FeedInspectorViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/6/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class FeedInspectorViewController: UITableViewController {
	
	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 500.0)
	
	var feed: Feed!
	@IBOutlet weak var nameTextField: UITextField!
	@IBOutlet weak var notifyAboutNewArticlesSwitch: UISwitch!
	@IBOutlet weak var alwaysShowReaderViewSwitch: UISwitch!
	@IBOutlet weak var homePageLabel: InteractiveLabel!
	@IBOutlet weak var feedURLLabel: InteractiveLabel!
	
	private var headerView: InspectorIconHeaderView?
	private var iconImage: IconImage {
		if let feedIcon = appDelegate.feedIconDownloader.icon(for: feed) {
			return feedIcon
		}
		if let favicon = appDelegate.faviconDownloader.favicon(for: feed) {
			return favicon
		}
		return FaviconGenerator.favicon(feed)
	}
	
	override func viewDidLoad() {
		tableView.register(InspectorIconHeaderView.self, forHeaderFooterViewReuseIdentifier: "SectionHeader")
		
		navigationItem.title = feed.nameForDisplay
		nameTextField.text = feed.nameForDisplay
		
		notifyAboutNewArticlesSwitch.setOn(feed.isNotifyAboutNewArticles ?? false, animated: false)
		alwaysShowReaderViewSwitch.setOn(feed.isArticleExtractorAlwaysOn ?? false, animated: false)

		homePageLabel.text = feed.homePageURL
		feedURLLabel.text = feed.url
		
		NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .FeedIconDidBecomeAvailable, object: nil)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		if nameTextField.text != feed.nameForDisplay {
			let nameText = nameTextField.text ?? ""
			let newName = nameText.isEmpty ? (feed.name ?? NSLocalizedString("Untitled", comment: "Feed name")) : nameText
			feed.rename(to: newName) { _ in }
		}
	}
	
	// MARK: Notifications
	@objc func feedIconDidBecomeAvailable(_ notification: Notification) {
		headerView?.iconView.iconImage = iconImage
	}
	
	@IBAction func notifyAboutNewArticlesChanged(_ sender: Any) {
		feed.isNotifyAboutNewArticles = notifyAboutNewArticlesSwitch.isOn
	}
	
	@IBAction func alwaysShowReaderViewChanged(_ sender: Any) {
		feed.isArticleExtractorAlwaysOn = alwaysShowReaderViewSwitch.isOn
	}
	
	@IBAction func done(_ sender: Any) {
		dismiss(animated: true)
	}
	
}

// MARK: Table View

extension FeedInspectorViewController {
	
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? 64.0 : super.tableView(tableView, heightForHeaderInSection: section)
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

extension FeedInspectorViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}
