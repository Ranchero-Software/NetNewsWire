//
//  RedditSelectAccountTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/12/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

import UIKit
import Account

class RedditSelectAccountTableViewController: UITableViewController {
	
	private var redditFeedProviders = [RedditFeedProvider]()
	
	var redditFeedType: RedditFeedType?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		redditFeedProviders = ExtensionPointManager.shared.activeExtensionPoints.values.compactMap { $0 as? RedditFeedProvider }
    }
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return redditFeedProviders.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
		cell.textLabel?.text = redditFeedProviders[indexPath.row].title
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let selectSort = UIStoryboard.redditAdd.instantiateController(ofType: RedditSelectSortTableViewController.self)
		selectSort.redditFeedType = redditFeedType
		selectSort.username = redditFeedProviders[indexPath.row].username
		navigationController?.pushViewController(selectSort, animated: true)
	}
	
}
