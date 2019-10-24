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

	override func setHighlighted(_ highlighted: Bool, animated: Bool) {
		super.setHighlighted(highlighted, animated: animated)
		updateVibrancy(animated: animated)
	}

	override func setSelected(_ selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)
		updateVibrancy(animated: animated)
	}
	
	override func applyThemeProperties() {
		super.applyThemeProperties()
		accountNameLabel?.highlightedTextColor = AppAssets.vibrantTextColor
	}

	func updateVibrancy(animated: Bool) {
		let tintColor = isHighlighted || isSelected ? AppAssets.vibrantTextColor : UIColor.label
		let duration = animated ? 0.6 : 0.0
		UIView.animate(withDuration: duration) {
			self.accountImage?.tintColor = tintColor
		}
	}
	
}
