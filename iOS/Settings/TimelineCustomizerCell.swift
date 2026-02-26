//
//  TimelineCustomizerCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 21/08/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit

enum SliderConfiguration {
	case numberOfLines
	case iconSize
}

final class TimelineCustomizerCell: UICollectionViewCell {
	@IBOutlet var slider: UISlider!

	var sliderConfiguration: SliderConfiguration! {
		didSet {
			switch sliderConfiguration {
			case .numberOfLines:
				slider.minimumValue = 1
				slider.maximumValue = 6
				slider.trackConfiguration = .init(allowsTickValuesOnly: true, numberOfTicks: 6)
				slider.value = Float(AppDefaults.shared.timelineNumberOfLines)
			case .iconSize:
				slider.minimumValue = 1
				slider.maximumValue = 3
				slider.trackConfiguration = .init(allowsTickValuesOnly: true, numberOfTicks: 3)
				slider.value = Float(AppDefaults.shared.timelineIconSize.rawValue)
			case .none:
				return
			}
		}
	}

	@IBAction func sliderValueChanges(_ sender: Any) {
		switch sliderConfiguration {
		case .numberOfLines:
			AppDefaults.shared.timelineNumberOfLines = Int(slider.value.rounded())
		case .iconSize:
			guard let iconSize = IconSize(rawValue: Int(slider.value.rounded())) else { return }
			AppDefaults.shared.timelineIconSize = iconSize
		case .none:
			return
		}
	}

	override func updateConfiguration(using state: UICellConfigurationState) {
		var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)
		backgroundConfig.backgroundColor = traitCollection.userInterfaceStyle == .dark ? .secondarySystemBackground : .white
		backgroundConfig.cornerRadius = 20
		self.backgroundConfiguration = backgroundConfig
	}

}
