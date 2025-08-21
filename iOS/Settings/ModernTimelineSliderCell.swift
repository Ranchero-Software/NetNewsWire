//
//  ModernTimelineSliderCell.swift
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

class ModernTimelineSliderCell: UITableViewCell {
	
	
	@IBOutlet weak var slider: UISlider!
	
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

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
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

}
