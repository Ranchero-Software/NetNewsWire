//
//  SettingsAccountTableViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class SettingsAccountTableViewCell: VibrantTableViewCell {

	@IBOutlet weak var accountImage: UIImageView!
	@IBOutlet weak var accountNameLabel: UILabel!

	override func updateVibrancy(animated: Bool) {
		super.updateVibrancy(animated: animated)
		updateLabelVibrancy(accountNameLabel, color: labelColor, animated: animated)
		
		let tintColor = isHighlighted || isSelected ? AppAssets.vibrantTextColor : UIColor.label
		UIView.animate(withDuration: duration(animated: animated)) {
			self.accountImage?.tintColor = tintColor
		}
	}
	
}
