//
//  AccountStatsFooterView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/7/26.
//

import AppKit

final class AccountStatsFooterView: NSView {

	private static let vacuumButtonTitle = NSLocalizedString("Vacuum Databases", comment: "Vacuum Databases button title")

	private let refreshButton: NSButton
	private let vacuumButton: NSButton
	private let vacuumSpinner = NSProgressIndicator()
	private let helpButton: NSButton
	private let explanationLabel: NSTextField

	init() {
		refreshButton = NSButton()
		refreshButton.bezelStyle = .rounded
		refreshButton.title = NSLocalizedString("Refresh", comment: "Refresh button title")
		refreshButton.translatesAutoresizingMaskIntoConstraints = false
		refreshButton.target = nil
		refreshButton.action = #selector(AccountStatsViewController.refresh(_:))

		vacuumButton = NSButton()
		vacuumButton.bezelStyle = .rounded
		vacuumButton.title = Self.vacuumButtonTitle
		vacuumButton.translatesAutoresizingMaskIntoConstraints = false
		vacuumButton.target = nil
		vacuumButton.action = #selector(AccountStatsViewController.vacuum(_:))

		helpButton = NSButton()
		helpButton.bezelStyle = .helpButton
		helpButton.title = ""
		helpButton.translatesAutoresizingMaskIntoConstraints = false
		helpButton.setAccessibilityLabel(NSLocalizedString("Help — opens in browser", comment: "Help button accessibility label"))
		helpButton.target = nil
		helpButton.action = #selector(AccountStatsViewController.showHelp(_:))

		explanationLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("Vacuuming may make databases faster.", comment: "Vacuum explanation text"))
		explanationLabel.translatesAutoresizingMaskIntoConstraints = false
		explanationLabel.font = NSFont.systemFont(ofSize: AccountStatsLayout.bottomBarFontSize)
		explanationLabel.textColor = .secondaryLabelColor
		explanationLabel.alignment = .natural

		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false

		vacuumSpinner.translatesAutoresizingMaskIntoConstraints = false
		vacuumSpinner.style = .spinning
		vacuumSpinner.controlSize = .small
		vacuumSpinner.isHidden = true
		vacuumSpinner.isIndeterminate = true

		// Spinner is centered inside the button so it visually replaces the title during vacuum.
		vacuumButton.addSubview(vacuumSpinner)

		let divider = NSBox()
		divider.boxType = .separator
		divider.translatesAutoresizingMaskIntoConstraints = false

		let background = NSVisualEffectView()
		background.translatesAutoresizingMaskIntoConstraints = false
		background.blendingMode = .withinWindow
		background.material = .titlebar

		// Empty view between the helper text and the Refresh button — absorbs slack
		// so the helper text stays next to the Vacuum Databases button on the left
		// and the Refresh button stays pinned to the trailing edge.
		let spacer = NSView()
		spacer.translatesAutoresizingMaskIntoConstraints = false

		let row = NSStackView(views: [vacuumButton, explanationLabel, spacer, refreshButton, helpButton])
		row.translatesAutoresizingMaskIntoConstraints = false
		row.orientation = .horizontal
		row.alignment = .centerY
		row.spacing = 8
		row.distribution = .fill

		spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
		spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

		// Helper text sizes to its content so it sits next to the Vacuum button.
		explanationLabel.setContentHuggingPriority(.required, for: .horizontal)
		explanationLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
		refreshButton.setContentHuggingPriority(.required, for: .horizontal)
		vacuumButton.setContentHuggingPriority(.required, for: .horizontal)
		helpButton.setContentHuggingPriority(.required, for: .horizontal)

		addSubview(divider)
		addSubview(background)
		addSubview(row)

		let padding = AccountStatsLayout.horizontalPadding
		let spacing = AccountStatsLayout.verticalSpacing

		NSLayoutConstraint.activate([
			divider.topAnchor.constraint(equalTo: topAnchor),
			divider.leadingAnchor.constraint(equalTo: leadingAnchor),
			divider.trailingAnchor.constraint(equalTo: trailingAnchor),

			background.topAnchor.constraint(equalTo: divider.bottomAnchor),
			background.leadingAnchor.constraint(equalTo: leadingAnchor),
			background.trailingAnchor.constraint(equalTo: trailingAnchor),
			background.bottomAnchor.constraint(equalTo: bottomAnchor),

			row.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: spacing),
			row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
			row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
			row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -spacing),

			vacuumButton.widthAnchor.constraint(equalToConstant: AccountStatsLayout.buttonWidth),
			refreshButton.widthAnchor.constraint(equalTo: vacuumButton.widthAnchor),

			vacuumSpinner.centerXAnchor.constraint(equalTo: vacuumButton.centerXAnchor),
			vacuumSpinner.centerYAnchor.constraint(equalTo: vacuumButton.centerYAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not supported")
	}

	func updateVacuumState(_ isVacuuming: Bool) {
		vacuumButton.isEnabled = !isVacuuming
		vacuumButton.title = isVacuuming ? "" : Self.vacuumButtonTitle
		vacuumSpinner.isHidden = !isVacuuming
		if isVacuuming {
			vacuumSpinner.startAnimation(nil)
		} else {
			vacuumSpinner.stopAnimation(nil)
		}
	}
}
