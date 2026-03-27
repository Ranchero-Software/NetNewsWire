//
//  CloudKitStatsCleanUpStatusView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/24/26.
//

import AppKit

final class CloudKitStatsCleanUpStatusView: NSView {

	let progressBar = NSProgressIndicator()
	let cancelButton = NSButton()
	let phaseTextField = NSTextField(labelWithString: "")

	init() {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false

		progressBar.style = .bar
		progressBar.isIndeterminate = false
		progressBar.minValue = 0
		progressBar.maxValue = 1.0
		progressBar.doubleValue = 0
		progressBar.translatesAutoresizingMaskIntoConstraints = false
		progressBar.setAccessibilityLabel(NSLocalizedString("Cleanup progress", comment: "Progress bar accessibility label"))

		cancelButton.bezelStyle = .rounded
		cancelButton.title = NSLocalizedString("Cancel", comment: "Cancel button")
		cancelButton.translatesAutoresizingMaskIntoConstraints = false
		cancelButton.widthAnchor.constraint(equalToConstant: CloudKitStatsLayout.buttonWidth).isActive = true

		phaseTextField.textColor = .secondaryLabelColor
		phaseTextField.font = .systemFont(ofSize: NSFont.systemFontSize)
		phaseTextField.translatesAutoresizingMaskIntoConstraints = false

		addSubview(progressBar)
		addSubview(cancelButton)
		addSubview(phaseTextField)

		NSLayoutConstraint.activate([
			progressBar.leadingAnchor.constraint(equalTo: leadingAnchor),
			progressBar.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
			cancelButton.leadingAnchor.constraint(equalTo: progressBar.trailingAnchor, constant: CloudKitStatsLayout.buttonTextGap),
			cancelButton.trailingAnchor.constraint(equalTo: trailingAnchor),
			cancelButton.topAnchor.constraint(equalTo: topAnchor),

			phaseTextField.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: CloudKitStatsLayout.rowSpacing),
			phaseTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
			phaseTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
			phaseTextField.bottomAnchor.constraint(equalTo: bottomAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
