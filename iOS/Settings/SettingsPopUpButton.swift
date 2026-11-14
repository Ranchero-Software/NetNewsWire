//
//  SettingsPopUpButton.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/14/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

extension UIButton {

	/// A pop-up button for a Settings row. Its title is the current choice.
	static func makeSettingsPopUpButton() -> UIButton {
		var configuration = UIButton.Configuration.plain()
		configuration.baseForegroundColor = .secondaryLabel
		let button = UIButton(configuration: configuration)
		button.showsMenuAsPrimaryAction = true
		button.changesSelectionAsPrimaryAction = true
		return button
	}
}

extension UITableViewCell {

	/// Auto Layout lets the button resize itself when choosing an item changes its title.
	/// The accessibility label names the setting, since the button’s title is only the current choice.
	func addSettingsPopUpButton(_ button: UIButton, accessibilityLabel: String) {
		button.accessibilityLabel = accessibilityLabel
		button.translatesAutoresizingMaskIntoConstraints = false
		button.setContentCompressionResistancePriority(.required, for: .horizontal)
		contentView.addSubview(button)
		NSLayoutConstraint.activate([
			button.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
		])
	}
}
