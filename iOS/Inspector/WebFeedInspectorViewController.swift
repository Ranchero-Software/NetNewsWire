//
//  WebFeedInspectorViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/6/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import SafariServices

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
		if let favicon = appDelegate.faviconDownloader.faviconAsIcon(for: webFeed) {
			return favicon
		}
		return FaviconGenerator.favicon(webFeed)
	}
	
	private let homePageIndexPath = IndexPath(row: 0, section: 1)
	
	private var shouldHideHomePageSection: Bool {
		return webFeed.homePageURL == nil
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
	
	/// Returns a new indexPath, taking into consideration any
	/// conditions that may require the tableView to be
	/// displayed differently than what is setup in the storyboard.
	private func shift(_ indexPath: IndexPath) -> IndexPath {
		return IndexPath(row: indexPath.row, section: shift(indexPath.section))
	}
	
	/// Returns a new section, taking into consideration any
	/// conditions that may require the tableView to be
	/// displayed differently than what is setup in the storyboard.
	private func shift(_ section: Int) -> Int {
		if section >= homePageIndexPath.section && shouldHideHomePageSection {
			return section + 1
		}
		return section
	}

	
}

// MARK: Table View

extension WebFeedInspectorViewController {

	override func numberOfSections(in tableView: UITableView) -> Int {
		let numberOfSections = super.numberOfSections(in: tableView)
		return shouldHideHomePageSection ? numberOfSections - 1 : numberOfSections
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return super.tableView(tableView, numberOfRowsInSection: shift(section))
	}
	
	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? ImageHeaderView.rowHeight : super.tableView(tableView, heightForHeaderInSection: shift(section))
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		super.tableView(tableView, cellForRowAt: shift(indexPath))
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		super.tableView(tableView, titleForHeaderInSection: shift(section))
	}
	
	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if shift(section) == 0 {
			headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SectionHeader") as? InspectorIconHeaderView
			headerView?.iconView.iconImage = iconImage
			return headerView
		} else {
			return super.tableView(tableView, viewForHeaderInSection: shift(section))
		}
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if shift(indexPath) == homePageIndexPath,
			let homePageUrlString = webFeed.homePageURL,
			let homePageUrl = URL(string: homePageUrlString) {
			
			let safari = SFSafariViewController(url: homePageUrl)
			safari.modalPresentationStyle = .pageSheet
			present(safari, animated: true) {
				tableView.deselectRow(at: indexPath, animated: true)
			}
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
