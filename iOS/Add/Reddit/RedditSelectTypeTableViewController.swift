//
//  RedditSelectTypeTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/12/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class RedditSelectTypeTableViewController: UITableViewController {
	
	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true)
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch indexPath.row {
		case 0:
			let redditFeedProviders = ExtensionPointManager.shared.activeExtensionPoints.values.compactMap { $0 as? RedditFeedProvider }
			if redditFeedProviders.count == 1 {
				let selectSort = UIStoryboard.redditAdd.instantiateController(ofType: RedditSelectSortTableViewController.self)
				selectSort.redditFeedType = .home
				selectSort.username = redditFeedProviders.first!.username
				navigationController?.pushViewController(selectSort, animated: true)
			} else {
				let selectAccount = UIStoryboard.redditAdd.instantiateController(ofType: RedditSelectAccountTableViewController.self)
				selectAccount.redditFeedType = .home
				navigationController?.pushViewController(selectAccount, animated: true)
			}
		case 1:
			let selectSort = UIStoryboard.redditAdd.instantiateController(ofType: RedditSelectSortTableViewController.self)
			selectSort.redditFeedType = .popular
			navigationController?.pushViewController(selectSort, animated: true)
		case 2:
			let selectSort = UIStoryboard.redditAdd.instantiateController(ofType: RedditSelectSortTableViewController.self)
			selectSort.redditFeedType = .all
			navigationController?.pushViewController(selectSort, animated: true)
		case 3:
			let enterDetail = UIStoryboard.redditAdd.instantiateController(ofType: RedditEnterDetailTableViewController.self)
			enterDetail.redditFeedType = .subreddit
			navigationController?.pushViewController(enterDetail, animated: true)
		default:
			fatalError()
		}
	}
	
}
