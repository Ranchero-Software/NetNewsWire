//
//  NNWTableViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Jim Correia on 9/2/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class NNWTableViewCell: UITableViewCell {
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		commonInit()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	private func commonInit() {
		applyThemeProperties()
	}
	
	/// Subclass overrides should call super
	func applyThemeProperties() {
		let selectedBackgroundView = UIView(frame: .zero)
		selectedBackgroundView.backgroundColor = AppAssets.primaryAccentColor
		self.selectedBackgroundView = selectedBackgroundView
	}
}
