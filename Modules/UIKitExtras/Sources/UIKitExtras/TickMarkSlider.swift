//
//  TickMarkSlider.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

public final class TickMarkSlider: UISlider {

	private var enableFeedback = false
	private let feedbackGenerator = UISelectionFeedbackGenerator()
	
	private var roundedValue: Float?
	public override var value: Float {
		didSet {
			let testValue = value.rounded()
			if testValue != roundedValue && enableFeedback && value.truncatingRemainder(dividingBy: 1) == 0 {
				roundedValue = testValue
				feedbackGenerator.selectionChanged()
			}
		}
	}
	
	public func addTickMarks(color: UIColor) {

		enableFeedback = true
		
		let numberOfGaps = Int(maximumValue) - Int(minimumValue)
		
		var gapLayoutGuides = [UILayoutGuide]()
		
		for i in 0...numberOfGaps {
			
			let tick = UIView()
			tick.translatesAutoresizingMaskIntoConstraints = false
			tick.backgroundColor = backgroundColor
			insertSubview(tick, at: 0)

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
	
	public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
		let result = super.continueTracking(touch, with: event)
		value = value.rounded()
		return result
	}

	public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
		value = value.rounded()
	}
}
