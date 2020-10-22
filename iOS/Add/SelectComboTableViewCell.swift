//
//  SelectComboTableViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/23/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

class SelectComboTableViewCell: VibrantTableViewCell {

	@IBOutlet weak var icon: UIImageView!
	@IBOutlet weak var label: UILabel!
	
	override func updateVibrancy(animated: Bool) {
		super.updateVibrancy(animated: animated)
		
		let iconTintColor = isHighlighted || isSelected ? AppAssets.vibrantTextColor : UIColor.label
		if animated {
			UIView.animate(withDuration: Self.duration) {
				self.icon.tintColor = iconTintColor
			}
		} else {
			self.icon.tintColor = iconTintColor
		}
		
		updateLabelVibrancy(label, color: labelColor, animated: animated)
	}
	
}
