//
//  ImageHeaderView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/3/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class ImageHeaderView: UITableViewHeaderFooterView {

	static let rowHeight = CGFloat(integerLiteral: 88)
	
	var imageView = UIImageView()
	
	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		commonInit()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	func commonInit() {
		imageView.tintColor = UIColor.label
		imageView.contentMode = .scaleAspectFit
		addSubview(imageView)
	}

	override func layoutSubviews() {
		let x = (bounds.width - 48.0) / 2
		let y = (bounds.height - 48.0) / 2
		imageView.frame = CGRect(x: x, y: y, width: 48.0, height: 48.0)
	}
}
