//
//  SelectComboTableViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/23/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

final class SelectComboTableViewCell: VibrantTableViewCell {
	@IBOutlet var icon: UIImageView!
	@IBOutlet var label: UILabel!

	override func updateVibrancy(animated: Bool) {
		super.updateVibrancy(animated: animated)

		let iconTintColor = isHighlighted || isSelected ? Assets.Colors.vibrantText : UIColor.label
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
