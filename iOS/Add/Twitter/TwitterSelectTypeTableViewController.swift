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
	
	private var twitterFeedProviders = [TwitterFeedProvider]()

	weak var delegate: SelectURLBuilderDelegate?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		twitterFeedProviders = ExtensionPointManager.shared.activeExtensionPoints.values.compactMap { $0 as? TwitterFeedProvider }
    }

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = super.tableView(tableView, cellForRowAt: indexPath)
		if indexPath.row < 2 {
			if twitterFeedProviders.count > 1 {
				cell.accessoryType = .disclosureIndicator
			}
		}
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch indexPath.row {
		case 0:
			if twitterFeedProviders.count == 1 {
				let username = twitterFeedProviders.first!.screenName
				if let url = TwitterFeedProvider.buildURL(.homeTimeline, username: username, screenName: nil, searchField: nil) {
					delegate?.selectURLBuilderDidBuildURL(url)
				}
				dismiss(animated: true)
			} else {
				let selectAccount = UIStoryboard.twitterAdd.instantiateController(ofType: TwitterSelectAccountTableViewController.self)
				selectAccount.twitterFeedType = .homeTimeline
				selectAccount.delegate = delegate
				navigationController?.pushViewController(selectAccount, animated: true)
			}
		case 1:
			if twitterFeedProviders.count == 1 {
				let username = twitterFeedProviders.first!.screenName
				if let url = TwitterFeedProvider.buildURL(.mentions, username: username, screenName: nil, searchField: nil) {
					delegate?.selectURLBuilderDidBuildURL(url)
				}
				dismiss(animated: true)
			} else {
				let selectAccount = UIStoryboard.twitterAdd.instantiateController(ofType: TwitterSelectAccountTableViewController.self)
				selectAccount.twitterFeedType = .mentions
				selectAccount.delegate = delegate
				navigationController?.pushViewController(selectAccount, animated: true)
			}
		case 2:
			let enterDetail = UIStoryboard.twitterAdd.instantiateController(ofType: TwitterEnterDetailTableViewController.self)
			enterDetail.twitterFeedType = .screenName
			enterDetail.delegate = delegate
			navigationController?.pushViewController(enterDetail, animated: true)
		case 3:
			let enterDetail = UIStoryboard.twitterAdd.instantiateController(ofType: TwitterEnterDetailTableViewController.self)
			enterDetail.twitterFeedType = .search
			enterDetail.delegate = delegate
			navigationController?.pushViewController(enterDetail, animated: true)
		default:
			fatalError()
		}
	}
	
}
