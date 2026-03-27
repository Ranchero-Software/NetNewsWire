//
//  CloudKitStatsScanStatusView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/24/26.
//

import AppKit

final class CloudKitStatsScanStatusView: NSView {

	let spinner = NSProgressIndicator()
	let statusIcon = NSImageView()
	let statusTextField = NSTextField(labelWithString: "")
	let actionButton = NSButton()

	private(set) var statusTextLeadingToSpinner: NSLayoutConstraint!
	private(set) var statusTextLeadingToContainer: NSLayoutConstraint!

	init() {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false

		spinner.style = .spinning
		spinner.controlSize = .small
		spinner.translatesAutoresizingMaskIntoConstraints = false
		spinner.setAccessibilityLabel(NSLocalizedString("Scanning", comment: "Spinner accessibility label"))
		spinner.startAnimation(nil)

		statusIcon.translatesAutoresizingMaskIntoConstraints = false
		statusIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: NSLocalizedString("Completed", comment: "Status icon accessibility description"))
		statusIcon.contentTintColor = .systemGreen
		statusIcon.isHidden = true

		statusTextField.translatesAutoresizingMaskIntoConstraints = false
		statusTextField.textColor = .secondaryLabelColor
		statusTextField.font = .systemFont(ofSize: NSFont.systemFontSize)
		statusTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

		actionButton.translatesAutoresizingMaskIntoConstraints = false
		actionButton.bezelStyle = .rounded
		actionButton.title = NSLocalizedString("Cancel", comment: "Cancel button")
		actionButton.widthAnchor.constraint(equalToConstant: CloudKitStatsLayout.buttonWidth).isActive = true

		addSubview(spinner)
		addSubview(statusIcon)
		addSubview(statusTextField)
		addSubview(actionButton)

		statusTextLeadingToSpinner = statusTextField.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: CloudKitStatsLayout.spinnerTextGap)
		statusTextLeadingToContainer = statusTextField.leadingAnchor.constraint(equalTo: leadingAnchor)

		NSLayoutConstraint.activate([
			spinner.leadingAnchor.constraint(equalTo: leadingAnchor),
			spinner.centerYAnchor.constraint(equalTo: statusTextField.centerYAnchor),

			statusIcon.leadingAnchor.constraint(equalTo: leadingAnchor),
			statusIcon.centerYAnchor.constraint(equalTo: statusTextField.centerYAnchor),

			statusTextLeadingToSpinner,

			actionButton.topAnchor.constraint(equalTo: topAnchor),
			actionButton.bottomAnchor.constraint(equalTo: bottomAnchor),
			statusTextField.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),

			actionButton.leadingAnchor.constraint(greaterThanOrEqualTo: statusTextField.trailingAnchor, constant: CloudKitStatsLayout.buttonTextGap),
			actionButton.trailingAnchor.constraint(equalTo: trailingAnchor),
			actionButton.lastBaselineAnchor.constraint(equalTo: statusTextField.lastBaselineAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
