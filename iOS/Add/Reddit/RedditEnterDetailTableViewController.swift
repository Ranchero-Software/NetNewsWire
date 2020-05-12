//
//  RedditEnterDetailTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/12/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

import UIKit
import Account

class RedditEnterDetailTableViewController: UITableViewController, SelectURLBuilder {
	
	@IBOutlet weak var detailTextField: UITextField!
	
	var nextBarButtonItem = UIBarButtonItem()
	var redditFeedType: RedditFeedType?
	weak var delegate: SelectURLBuilderDelegate?
	
    override func viewDidLoad() {
        super.viewDidLoad()

		nextBarButtonItem.title = NSLocalizedString("Next", comment: "Next")
		nextBarButtonItem.style = .plain
		nextBarButtonItem.target = self
		nextBarButtonItem.action = #selector(nextScene)
		navigationItem.rightBarButtonItem = nextBarButtonItem

		detailTextField.delegate = self
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: detailTextField)

		updateUI()
    }

	@objc func nextScene() {
		let selectSort = UIStoryboard.redditAdd.instantiateController(ofType: RedditSelectSortTableViewController.self)
		selectSort.redditFeedType = redditFeedType
		selectSort.subreddit = detailTextField.text?.collapsingWhitespace
		selectSort.delegate = delegate
		navigationController?.pushViewController(selectSort, animated: true)
	}
	
	@objc func textDidChange(_ note: Notification) {
		updateUI()
	}

}

extension RedditEnterDetailTableViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}

private extension RedditEnterDetailTableViewController {
	
	func updateUI() {
		nextBarButtonItem.isEnabled = !(detailTextField.text?.isEmpty ?? false)
	}
	
}
