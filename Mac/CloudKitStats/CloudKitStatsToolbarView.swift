//
//  CloudKitStatsToolbarView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/24/26.
//

import AppKit

final class CloudKitStatsToolbarView: NSView {

	let helpButton: NSButton
	let shareButton: NSButton
	let cleanUpButton: NSButton

	init() {
		helpButton = NSButton()
		helpButton.bezelStyle = .helpButton
		helpButton.title = ""
		helpButton.translatesAutoresizingMaskIntoConstraints = false
		helpButton.setAccessibilityLabel(NSLocalizedString("Help — opens in browser", comment: "Help button accessibility label"))
		helpButton.target = nil
		helpButton.action = #selector(CloudKitStatsViewController.showHelp(_:))

		shareButton = NSButton()
		shareButton.bezelStyle = .rounded
		shareButton.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: NSLocalizedString("Share", comment: "Share button accessibility description"))
		shareButton.translatesAutoresizingMaskIntoConstraints = false
		shareButton.target = nil
		shareButton.action = #selector(CloudKitStatsViewController.shareStats(_:))

		cleanUpButton = NSButton()
		cleanUpButton.bezelStyle = .rounded
		cleanUpButton.title = NSLocalizedString("Clean Up", comment: "Clean Up button title")
		cleanUpButton.translatesAutoresizingMaskIntoConstraints = false
		cleanUpButton.target = nil
		cleanUpButton.action = #selector(CloudKitStatsViewController.cleanUp(_:))

		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false

		let divider = CloudKitStatsLayout.makeDivider()

		let background = NSVisualEffectView()
		background.translatesAutoresizingMaskIntoConstraints = false
		background.blendingMode = .withinWindow
		background.material = .titlebar

		addSubview(divider)
		addSubview(background)
		addSubview(helpButton)
		addSubview(shareButton)
		addSubview(cleanUpButton)

		NSLayoutConstraint.activate([
			divider.topAnchor.constraint(equalTo: topAnchor),
			divider.leadingAnchor.constraint(equalTo: leadingAnchor),
			divider.trailingAnchor.constraint(equalTo: trailingAnchor),

			background.topAnchor.constraint(equalTo: divider.bottomAnchor),
			background.leadingAnchor.constraint(equalTo: leadingAnchor),
			background.trailingAnchor.constraint(equalTo: trailingAnchor),
			background.bottomAnchor.constraint(equalTo: bottomAnchor),

			helpButton.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: CloudKitStatsLayout.sectionSpacing),
			helpButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: CloudKitStatsLayout.horizontalPadding),
			helpButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -CloudKitStatsLayout.sectionSpacing),

			shareButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -CloudKitStatsLayout.horizontalPadding),
			shareButton.centerYAnchor.constraint(equalTo: helpButton.centerYAnchor),

			cleanUpButton.centerXAnchor.constraint(equalTo: centerXAnchor),
			cleanUpButton.centerYAnchor.constraint(equalTo: helpButton.centerYAnchor),
			cleanUpButton.widthAnchor.constraint(equalToConstant: CloudKitStatsLayout.buttonWidth)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
