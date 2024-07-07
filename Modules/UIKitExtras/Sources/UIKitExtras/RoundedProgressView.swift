//
//  RoundedProgressView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

public final class RoundedProgressView: UIProgressView {

	public override func layoutSubviews() {
		super.layoutSubviews()
		for subview in subviews {
			subview.layer.masksToBounds = true
			subview.layer.cornerRadius = bounds.height / 2.0
		}
	}
}
