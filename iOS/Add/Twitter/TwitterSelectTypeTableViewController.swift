//
//  TwitterSelectTypeTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/23/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class TwitterSelectTypeTableViewController: UITableViewController {
	
	private var twitterFeedProviders = [TwitterFeedProvider]()

    override func viewDidLoad() {
        super.viewDidLoad()
		twitterFeedProviders = ExtensionPointManager.shared.activeExtensionPoints.values.compactMap { $0 as? TwitterFeedProvider }
    }

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true)
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
				let url = TwitterFeedProvider.buildURL(.homeTimeline, username: username, screenName: nil, searchField: nil)?.absoluteString
				pushAddFeedController(url)
			} else {
				let selectAccount = UIStoryboard.twitterAdd.instantiateController(ofType: TwitterSelectAccountTableViewController.self)
				selectAccount.twitterFeedType = .homeTimeline
				navigationController?.pushViewController(selectAccount, animated: true)
			}
		case 1:
			if twitterFeedProviders.count == 1 {
				let username = twitterFeedProviders.first!.screenName
				let url = TwitterFeedProvider.buildURL(.mentions, username: username, screenName: nil, searchField: nil)?.absoluteString
				pushAddFeedController(url)
			} else {
				let selectAccount = UIStoryboard.twitterAdd.instantiateController(ofType: TwitterSelectAccountTableViewController.self)
				selectAccount.twitterFeedType = .mentions
				navigationController?.pushViewController(selectAccount, animated: true)
			}
		case 2:
			let enterDetail = UIStoryboard.twitterAdd.instantiateController(ofType: TwitterEnterDetailTableViewController.self)
			enterDetail.twitterFeedType = .screenName
			navigationController?.pushViewController(enterDetail, animated: true)
		case 3:
			let enterDetail = UIStoryboard.twitterAdd.instantiateController(ofType: TwitterEnterDetailTableViewController.self)
			enterDetail.twitterFeedType = .search
			navigationController?.pushViewController(enterDetail, animated: true)
		default:
			fatalError()
		}
	}
	
}

private extension TwitterSelectTypeTableViewController {
	
	func pushAddFeedController(_ url: String?) {
		let addViewController = UIStoryboard.add.instantiateViewController(withIdentifier: "AddWebFeedViewController") as! AddFeedViewController
		addViewController.addFeedType = .twitter
		addViewController.initialFeed = url
		navigationController?.pushViewController(addViewController, animated: true)
	}
	
}
