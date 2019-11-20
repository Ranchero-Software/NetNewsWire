//
//  InspectorIconHeaderView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/6/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class InspectorIconHeaderView: UITableViewHeaderFooterView {

	var iconView = IconView()
	
	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		commonInit()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	func commonInit() {
		addSubview(iconView)
	}

	override func layoutSubviews() {
		let x = (bounds.width - 48.0) / 2
		let y = (bounds.height - 48.0) / 2
		iconView.frame = CGRect(x: x, y: y, width: 48.0, height: 48.0)
	}
}
