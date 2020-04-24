//
//  SettingsAccountTableViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class SettingsComboTableViewCell: VibrantTableViewCell {

	@IBOutlet weak var comboImage: UIImageView!
	@IBOutlet weak var comboNameLabel: UILabel!

	override func updateVibrancy(animated: Bool) {
		super.updateVibrancy(animated: animated)
		updateLabelVibrancy(comboNameLabel, color: labelColor, animated: animated)
		
		let tintColor = isHighlighted || isSelected ? AppAssets.vibrantTextColor : UIColor.label
		UIView.animate(withDuration: duration(animated: animated)) {
			self.comboImage?.tintColor = tintColor
		}
	}
	
}
