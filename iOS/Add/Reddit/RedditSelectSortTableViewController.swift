//
//  RedditSelectSortTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/12/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class RedditSelectSortTableViewController: UITableViewController, SelectURLBuilder {
	
	weak var delegate: SelectURLBuilderDelegate?
	var redditFeedType: RedditFeedType?
	var username: String?
	var subreddit: String?
	
    override func viewDidLoad() {
        super.viewDidLoad()
    }

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
		
		if let url = RedditFeedProvider.buildURL(redditFeedType, username: username, subreddit: subreddit, sort: sort) {
			delegate?.selectURLBuilderDidBuildURL(url)
		}
		dismiss(animated: true)
	}
	
}
