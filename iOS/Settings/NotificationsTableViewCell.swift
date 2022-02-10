//
//  NotificationsTableViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 26/01/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import UserNotifications


class NotificationsTableViewCell: VibrantBasicTableViewCell {

	@IBOutlet weak var notificationsSwitch: UISwitch!
	@IBOutlet weak var notificationsLabel: UILabel!
	@IBOutlet weak var notificationsImageView: UIImageView!
	var feed: WebFeed?
	
	
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
	
	func configure(_ webFeed: WebFeed) {
		self.feed = webFeed
		var isOn = false
		if webFeed.isNotifyAboutNewArticles == nil {
			isOn = false
		} else {
			isOn = webFeed.isNotifyAboutNewArticles!
		}
		notificationsSwitch.isOn = isOn
		notificationsSwitch.addTarget(self, action: #selector(toggleWebFeedNotification(_:)), for: .touchUpInside)
		notificationsLabel.text = webFeed.nameForDisplay
		notificationsImageView.image = IconImageCache.shared.imageFor(webFeed.feedID!)?.image
		notificationsImageView.layer.cornerRadius = 4
	}
	
	@objc
	private func toggleWebFeedNotification(_ sender: Any) {
		guard let feed = feed else {
			return
		}
		if feed.isNotifyAboutNewArticles == nil {
			feed.isNotifyAboutNewArticles = true
		}
		else {
			feed.isNotifyAboutNewArticles!.toggle()
		}
	}

}
