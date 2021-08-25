//
//  BrowserCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 22/8/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import UIKit

class BrowserCell: VibrantTableViewCell {

	@IBOutlet weak var browserName: UILabel!
	private var browser: Browser!
	
	override func updateVibrancy(animated: Bool) {
		super.updateVibrancy(animated: animated)
		updateLabelVibrancy(browserName, color: labelColor, animated: animated)
	}
	
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
	
	func configure(with browser: Browser) {
		browserName.text = browser.displayName
		self.browser = browser
		
		if AppDefaults.shared.browserPreference == browser.browserID {
			accessoryType = .checkmark
		} else {
			accessoryType = .none
		}
	}
	
	func updateBrowserSelection() {
		AppDefaults.shared.browserPreference = self.browser.browserID
	}

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
