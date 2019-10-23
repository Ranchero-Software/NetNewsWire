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
		let tintColor = isHighlighted || isSelected ? AppAssets.vibrantTextColor : UIColor.label
		accountImage?.tintColor = tintColor
		accountNameLabel?.highlightedTextColor = tintColor
	}

	override func setSelected(_ selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)
		let tintColor = isHighlighted || isSelected ? AppAssets.vibrantTextColor : UIColor.label
		accountImage?.tintColor = tintColor
		accountNameLabel?.highlightedTextColor = tintColor
	}
	
}
