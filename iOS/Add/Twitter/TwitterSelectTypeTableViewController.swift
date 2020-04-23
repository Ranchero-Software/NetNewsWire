//
//  TwitterSelectTypeTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/23/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class TwitterSelectTypeTableViewController: UITableViewController, SelectURLBuilder {
	
	weak var delegate: SelectURLBuilderDelegate?
	
    override func viewDidLoad() {
        super.viewDidLoad()
    }

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = super.tableView(tableView, cellForRowAt: indexPath)
		if indexPath.row < 2 {
			if findTwitterFeedProviders().count > 1 {
				cell.accessoryType = .disclosureIndicator
			}
		}
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch indexPath.row {
		case 0:
			let twitterFeedProviders = findTwitterFeedProviders()
			if twitterFeedProviders.count == 1 {
				let username = twitterFeedProviders.first!.screenName
				if let url = TwitterFeedProvider.buildURL(.homeTimeline, username: username, screenName: nil, searchField: nil) {
					delegate?.selectURLBuilderDidBuildURL(url)
				}
				dismiss(animated: true)
			} else {
				// TODO: Create a controller for the next scene...
			}
		case 1:
			let twitterFeedProviders = findTwitterFeedProviders()
			if twitterFeedProviders.count == 1 {
				let username = twitterFeedProviders.first!.screenName
				if let url = TwitterFeedProvider.buildURL(.mentions, username: username, screenName: nil, searchField: nil) {
					delegate?.selectURLBuilderDidBuildURL(url)
				}
				dismiss(animated: true)
			} else {
				// TODO: Create a controller for the next scene...
			}
		default:
			fatalError()
		}
	}
	
}

private extension TwitterSelectTypeTableViewController {
	
	func findTwitterFeedProviders() -> [TwitterFeedProvider] {
		return ExtensionPointManager.shared.activeExtensionPoints.values.compactMap { $0 as? TwitterFeedProvider }
	}
}
