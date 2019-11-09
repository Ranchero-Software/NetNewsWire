//
//  TickMarkSlider.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class TickMarkSlider: UISlider {

	func addTickMarks() {

		let numberOfGaps = Int(maximumValue) - Int(minimumValue)
		
		var gapLayoutGuides = [UILayoutGuide]()
		
		for i in 0...numberOfGaps {
			
			let tick = UIView()
			tick.translatesAutoresizingMaskIntoConstraints = false
			tick.backgroundColor = AppAssets.tickMarkColor
			insertSubview(tick, belowSubview: self)

			tick.widthAnchor.constraint(equalToConstant: 3).isActive = true
			tick.heightAnchor.constraint(equalToConstant: 10).isActive = true
			tick.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

			if i == 0 {
				tick.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
			}
			
			if let lastGapLayoutGuild = gapLayoutGuides.last {
				lastGapLayoutGuild.trailingAnchor.constraint(equalTo: tick.leadingAnchor).isActive = true
			}
			
			if i != numberOfGaps {
				let gapLayoutGuild = UILayoutGuide()
				gapLayoutGuides.append(gapLayoutGuild)
				addLayoutGuide(gapLayoutGuild)
				tick.trailingAnchor.constraint(equalTo: gapLayoutGuild.leadingAnchor).isActive = true
			} else {
				tick.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
			}
			
		}
		
		if let firstGapLayoutGuild = gapLayoutGuides.first {
			for i in 1..<gapLayoutGuides.count {
				gapLayoutGuides[i].widthAnchor.constraint(equalTo: firstGapLayoutGuild.widthAnchor).isActive = true
			}
		}
				
	}

	override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
		value = value.rounded()
	}
	
}
