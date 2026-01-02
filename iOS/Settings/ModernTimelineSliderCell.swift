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

final class ModernTimelineSliderCell: UITableViewCell {
	@IBOutlet var slider: UISlider!

	private let container = UIView()

	override func awakeFromNib() {
		MainActor.assumeIsolated {
			super.awakeFromNib()
			setup()
		}
	}

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}

	private func setup() {
		container.layer.cornerRadius = contentView.frame.height/2
		container.backgroundColor = .systemBackground
		container.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(container)
		contentView.sendSubviewToBack(container)

		NSLayoutConstraint.activate([
			container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
			container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0),
			container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
			container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
		])
		contentView.backgroundColor = .systemGroupedBackground
	}

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

}
