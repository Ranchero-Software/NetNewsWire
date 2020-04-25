//
//  TwitterEnterDetailTableViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/23/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class TwitterEnterDetailTableViewController: UITableViewController, SelectURLBuilder {
	
	@IBOutlet weak var detailTextField: UITextField!
	
	var doneBarButtonItem = UIBarButtonItem()
	var twitterFeedType: TwitterFeedType?
	weak var delegate: SelectURLBuilderDelegate?
	
    override func viewDidLoad() {
        super.viewDidLoad()

		doneBarButtonItem.title = NSLocalizedString("Done", comment: "Done")
		doneBarButtonItem.style = .done
		doneBarButtonItem.target = self
		doneBarButtonItem.action = #selector(done)
		navigationItem.rightBarButtonItem = doneBarButtonItem

		if case .screenName = twitterFeedType {
			navigationItem.title = NSLocalizedString("Enter Name", comment: "Enter Name")
			detailTextField.placeholder = NSLocalizedString("Screen Name", comment: "Screen Name")
		} else {
			navigationItem.title = NSLocalizedString("Enter Search", comment: "Enter Search")
			detailTextField.placeholder = NSLocalizedString("Search Term or #hashtag", comment: "Search Term")
		}

		detailTextField.delegate = self
		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: detailTextField)

		updateUI()
    }

	@objc func done() {
		guard let twitterFeedType = twitterFeedType, var text = detailTextField.text?.collapsingWhitespace else { return }
		
		if twitterFeedType == .screenName {
			if text.starts(with: "@") {
				text = String(text[text.index(text.startIndex, offsetBy: 1)..<text.endIndex])
			}
			if let url = TwitterFeedProvider.buildURL(twitterFeedType, username: nil, screenName: text, searchField: nil) {
				delegate?.selectURLBuilderDidBuildURL(url)
			}
		} else {
			if let url = TwitterFeedProvider.buildURL(twitterFeedType, username: nil, screenName: nil, searchField: text) {
				delegate?.selectURLBuilderDidBuildURL(url)
			}
		}
		
		dismiss(animated: true)
	}
	
	@objc func textDidChange(_ note: Notification) {
		updateUI()
	}

}

extension TwitterEnterDetailTableViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}

private extension TwitterEnterDetailTableViewController {
	
	func updateUI() {
		doneBarButtonItem.isEnabled = !(detailTextField.text?.isEmpty ?? false)
	}
	
}
