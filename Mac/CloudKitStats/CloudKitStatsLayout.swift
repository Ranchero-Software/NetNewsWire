//
//  CloudKitStatsLayout.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/24/26.
//

import AppKit

enum CloudKitStatsLayout {

	static let containerWidth: CGFloat = 400
	static let windowHeight: CGFloat = 530
	static let buttonWidth: CGFloat = 80
	static let sectionSpacing: CGFloat = 14
	static let horizontalPadding: CGFloat = 20
	static let rowSpacing: CGFloat = 6
	static let iconSize: CGFloat = 12
	static let iconLabelGap: CGFloat = 4
	static let spinnerTextGap: CGFloat = 6
	static let buttonTextGap: CGFloat = 8
	static let fetchingAlpha: CGFloat = 0.4
	static let animationDuration: CGFloat = 0.25
	static let starColor = Assets.Colors.star
	static let warningColor = NSColor.systemOrange

	@MainActor static func makeDivider() -> NSView {
		let divider = NSBox()
		divider.boxType = .separator
		divider.translatesAutoresizingMaskIntoConstraints = false
		return divider
	}

	@MainActor static func makeLabelWithIcon(_ text: String, symbolName: String, color: NSColor, iconOffset: CGFloat = 0) -> NSView {
		let container = NSView()
		container.translatesAutoresizingMaskIntoConstraints = false

		let icon = NSImageView()
		icon.translatesAutoresizingMaskIntoConstraints = false
		icon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: text)
		icon.contentTintColor = color
		icon.setContentHuggingPriority(.required, for: .horizontal)

		let label = NSTextField(labelWithString: text)
		label.translatesAutoresizingMaskIntoConstraints = false

		container.addSubview(icon)
		container.addSubview(label)

		NSLayoutConstraint.activate([
			label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
			label.topAnchor.constraint(equalTo: container.topAnchor),
			label.bottomAnchor.constraint(equalTo: container.bottomAnchor),

			icon.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: iconLabelGap),
			icon.centerYAnchor.constraint(equalTo: label.centerYAnchor, constant: iconOffset),
			icon.widthAnchor.constraint(equalToConstant: iconSize),
			icon.heightAnchor.constraint(equalToConstant: iconSize),
			icon.trailingAnchor.constraint(equalTo: container.trailingAnchor)
		])

		return container
	}

	@MainActor static func configureValueLabel(_ label: NSTextField) {
		label.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
		label.alignment = .right
	}

	static func formattedNumber(_ value: Int) -> String {
		NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
	}

	static func formattedCount(_ count: Int, singular: String, plural: String) -> String {
		let label = count == 1 ? singular : plural
		return "\(formattedNumber(count)) \(label)"
	}
}
