//
//  VibrantButton.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/22/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class VibrantButton: UIButton {

	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	private func commonInit() {
		setTitleColor(AppAssets.vibrantTextColor, for: .highlighted)
	}

	override var isHighlighted: Bool {
		didSet {
			backgroundColor = isHighlighted ? AppAssets.secondaryAccentColor : nil
			titleLabel?.alpha = 1
		}
	}

}
