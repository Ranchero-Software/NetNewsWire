//
//  RedditSelectSortTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/12/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class RedditSelectSortTableViewController: UITableViewController {
	
	var redditFeedType: RedditFeedType?
	var username: String?
	var subreddit: String?

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		let sort: RedditSort
		switch indexPath.row {
		case 0:
			sort = .best
		case 1:
			sort = .hot
		case 2:
			sort = .new
		case 3:
			sort = .top
		case 4:
			sort = .rising
		default:
			fatalError()
		}

		guard let redditFeedType = redditFeedType else { return }
		let url = RedditFeedProvider.buildURL(redditFeedType, username: username, subreddit: subreddit, sort: sort)?.absoluteString
		
		let addViewController = UIStoryboard.add.instantiateViewController(withIdentifier: "AddWebFeedViewController") as! AddFeedViewController
		addViewController.addFeedType = .reddit
		addViewController.initialFeed = url
		navigationController?.pushViewController(addViewController, animated: true)

	}
	
}
