//
//  AccountStatsFooterView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/7/26.
//

import AppKit

final class AccountStatsFooterView: NSView {

	private let totalsLabel = NSTextField(wrappingLabelWithString: "")
	private let refreshButton: NSButton
	private let vacuumButton: NSButton
	private let vacuumSpinner = NSProgressIndicator()
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
		vacuumButton.title = NSLocalizedString("Vacuum Databases", comment: "Vacuum Databases button title")
		vacuumButton.translatesAutoresizingMaskIntoConstraints = false
		vacuumButton.target = nil
		vacuumButton.action = #selector(AccountStatsViewController.vacuum(_:))

		explanationLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("Vacuuming may make databases faster.", comment: "Vacuum explanation text"))
		explanationLabel.translatesAutoresizingMaskIntoConstraints = false
		explanationLabel.font = NSFont.systemFont(ofSize: AccountStatsLayout.bottomBarFontSize)
		explanationLabel.textColor = .secondaryLabelColor

		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false

		totalsLabel.translatesAutoresizingMaskIntoConstraints = false
		totalsLabel.font = NSFont.systemFont(ofSize: AccountStatsLayout.bottomBarFontSize)
		totalsLabel.textColor = .secondaryLabelColor

		vacuumSpinner.translatesAutoresizingMaskIntoConstraints = false
		vacuumSpinner.style = .spinning
		vacuumSpinner.controlSize = .small
		vacuumSpinner.isHidden = true
		vacuumSpinner.isIndeterminate = true

		let divider = NSBox()
		divider.boxType = .separator
		divider.translatesAutoresizingMaskIntoConstraints = false

		let background = NSVisualEffectView()
		background.translatesAutoresizingMaskIntoConstraints = false
		background.blendingMode = .withinWindow
		background.material = .titlebar

		// Top row: totals leading, Refresh trailing.
		let topRow = NSStackView(views: [totalsLabel, refreshButton])
		topRow.translatesAutoresizingMaskIntoConstraints = false
		topRow.orientation = .horizontal
		topRow.alignment = .centerY
		topRow.spacing = 8
		topRow.distribution = .fill

		// Bottom row: prose leading, spinner + Vacuum trailing.
		let bottomRow = NSStackView(views: [explanationLabel, vacuumSpinner, vacuumButton])
		bottomRow.translatesAutoresizingMaskIntoConstraints = false
		bottomRow.orientation = .horizontal
		bottomRow.alignment = .centerY
		bottomRow.spacing = 8
		bottomRow.distribution = .fill

		// Let the text labels absorb extra horizontal space so buttons stay at the trailing edge.
		totalsLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
		totalsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		explanationLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
		explanationLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		refreshButton.setContentHuggingPriority(.required, for: .horizontal)
		vacuumButton.setContentHuggingPriority(.required, for: .horizontal)

		addSubview(divider)
		addSubview(background)
		addSubview(topRow)
		addSubview(bottomRow)

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

			topRow.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: spacing),
			topRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
			topRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),

			bottomRow.topAnchor.constraint(equalTo: topRow.bottomAnchor, constant: spacing),
			bottomRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
			bottomRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
			bottomRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -spacing),

			vacuumButton.widthAnchor.constraint(equalToConstant: AccountStatsLayout.buttonWidth),
			refreshButton.widthAnchor.constraint(equalTo: vacuumButton.widthAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not supported")
	}

	func updateTotals(_ model: AccountStatsViewModel) {
		let feeds = AccountStatsLayout.formattedNumber(model.totalFeedCount)
		let folders = AccountStatsLayout.formattedNumber(model.totalFolderCount)
		let articles = AccountStatsLayout.formattedNumber(model.totalArticleCount)
		let size = AccountStatsLayout.formattedSize(model.totalDatabaseSizeBytes)

		totalsLabel.stringValue = String(
			format: NSLocalizedString("%@ feeds, %@ folders, %@ articles, %@", comment: "Account stats totals line"),
			feeds, folders, articles, size
		)
	}

	func updateVacuumState(_ isVacuuming: Bool) {
		vacuumButton.isEnabled = !isVacuuming
		vacuumSpinner.isHidden = !isVacuuming
		if isVacuuming {
			vacuumSpinner.startAnimation(nil)
		} else {
			vacuumSpinner.stopAnimation(nil)
		}
	}
}
