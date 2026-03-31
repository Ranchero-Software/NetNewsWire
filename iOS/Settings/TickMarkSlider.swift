//
//  TickMarkSlider.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class TickMarkSlider: UISlider {

	private var enableFeedback = false
	private let feedbackGenerator = UISelectionFeedbackGenerator()

	private var roundedValue: Float?
	override var value: Float {
		didSet {
			let testValue = value.rounded()
			if testValue != roundedValue && enableFeedback && value.truncatingRemainder(dividingBy: 1) == 0 {
				roundedValue = testValue
				feedbackGenerator.selectionChanged()
			}
		}
	}

	func addTickMarks() {
		if #available(iOS 26, *) {
			return
		}

		enableFeedback = true

		let numberOfGaps = Int(maximumValue) - Int(minimumValue)

		var gapLayoutGuides = [UILayoutGuide]()

		for i in 0...numberOfGaps {

			let tick = UIView()
			tick.translatesAutoresizingMaskIntoConstraints = false
			tick.backgroundColor = .tertiaryLabel
			insertSubview(tick, at: 0)

			tick.widthAnchor.constraint(equalToConstant: 3).isActive = true
			tick.heightAnchor.constraint(equalToConstant: 10).isActive = true
			tick.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true

			if i == 0 {
				tick.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
			}

			if let lastGapLayoutGuide = gapLayoutGuides.last {
				lastGapLayoutGuide.trailingAnchor.constraint(equalTo: tick.leadingAnchor).isActive = true
			}

			if i != numberOfGaps {
				let gapLayoutGuide = UILayoutGuide()
				gapLayoutGuides.append(gapLayoutGuide)
				addLayoutGuide(gapLayoutGuide)
				tick.trailingAnchor.constraint(equalTo: gapLayoutGuide.leadingAnchor).isActive = true
			} else {
				tick.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
			}
		}

		if let firstGapLayoutGuide = gapLayoutGuides.first {
			for i in 1..<gapLayoutGuides.count {
				gapLayoutGuides[i].widthAnchor.constraint(equalTo: firstGapLayoutGuide.widthAnchor).isActive = true
			}
		}
	}

	override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
		if #available(iOS 26, *) {
			return super.continueTracking(touch, with: event)
		}
		let result = super.continueTracking(touch, with: event)
		value = value.rounded()
		return result
	}

	override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
		if #available(iOS 26, *) {
			super.endTracking(touch, with: event)
			return
		}
		value = value.rounded()
	}
}
