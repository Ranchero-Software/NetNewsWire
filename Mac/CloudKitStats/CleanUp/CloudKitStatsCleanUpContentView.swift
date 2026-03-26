//
//  CloudKitStatsCleanUpContentView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/24/26.
//

import AppKit

final class CloudKitStatsCleanUpContentView: NSView {

	let readContentDeletedLabel = NSTextField(labelWithString: "0")
	let unreadContentDeletedLabel = NSTextField(labelWithString: "0")

	let readContentDeletedRow: NSView
	let unreadContentDeletedRow: NSView

	let errorTextField = NSTextField(wrappingLabelWithString: "")
	let refreshButton = NSButton()

	let navigationButtonGroup = NSView()
	let returnToPreviousResultsButton = NSButton()
	let refreshScanButton = NSButton()

	private let statsStackView = NSStackView()

	init() {
		readContentDeletedRow = Self.makeStatRow(NSLocalizedString("Read Content Deleted", comment: "Cleanup stat row label"), valueLabel: readContentDeletedLabel)
		unreadContentDeletedRow = Self.makeStatRow(NSLocalizedString("Unread Content Deleted", comment: "Cleanup stat row label"), valueLabel: unreadContentDeletedLabel)

		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false

		configureStatsStack()
		configureErrorViews()
		configureNavigationButtons()

		addSubview(statsStackView)
		addSubview(navigationButtonGroup)

		let availableSpace = NSLayoutGuide()
		addLayoutGuide(availableSpace)

		NSLayoutConstraint.activate([
			statsStackView.topAnchor.constraint(equalTo: topAnchor),
			statsStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
			statsStackView.trailingAnchor.constraint(equalTo: trailingAnchor),

			availableSpace.topAnchor.constraint(equalTo: statsStackView.bottomAnchor),
			availableSpace.bottomAnchor.constraint(equalTo: bottomAnchor),

			navigationButtonGroup.centerYAnchor.constraint(equalTo: availableSpace.centerYAnchor),
			navigationButtonGroup.centerXAnchor.constraint(equalTo: centerXAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

// MARK: - Private

private extension CloudKitStatsCleanUpContentView {

	func configureStatsStack() {
		statsStackView.translatesAutoresizingMaskIntoConstraints = false
		statsStackView.orientation = .vertical
		statsStackView.alignment = .leading
		statsStackView.spacing = CloudKitStatsLayout.rowSpacing

		statsStackView.addArrangedSubview(readContentDeletedRow)
		statsStackView.addArrangedSubview(unreadContentDeletedRow)
		statsStackView.addArrangedSubview(errorTextField)
		statsStackView.addArrangedSubview(refreshButton)

		NSLayoutConstraint.activate([
			readContentDeletedRow.widthAnchor.constraint(equalTo: statsStackView.widthAnchor),
			unreadContentDeletedRow.widthAnchor.constraint(equalTo: statsStackView.widthAnchor),
			errorTextField.widthAnchor.constraint(equalTo: statsStackView.widthAnchor)
		])
	}

	func configureErrorViews() {
		errorTextField.textColor = .secondaryLabelColor
		errorTextField.font = .systemFont(ofSize: NSFont.systemFontSize)
		errorTextField.isHidden = true

		refreshButton.bezelStyle = .rounded
		refreshButton.title = NSLocalizedString("Refresh", comment: "Refresh button")
		refreshButton.translatesAutoresizingMaskIntoConstraints = false
		refreshButton.isHidden = true
	}

	func configureNavigationButtons() {
		returnToPreviousResultsButton.bezelStyle = .rounded
		returnToPreviousResultsButton.title = NSLocalizedString("Return to Previous Scan Results", comment: "Return to previous scan results button")
		returnToPreviousResultsButton.translatesAutoresizingMaskIntoConstraints = false

		refreshScanButton.bezelStyle = .rounded
		refreshScanButton.title = NSLocalizedString("Refresh Scan", comment: "Refresh scan button")
		refreshScanButton.translatesAutoresizingMaskIntoConstraints = false

		navigationButtonGroup.translatesAutoresizingMaskIntoConstraints = false
		navigationButtonGroup.isHidden = true
		navigationButtonGroup.addSubview(returnToPreviousResultsButton)
		navigationButtonGroup.addSubview(refreshScanButton)

		NSLayoutConstraint.activate([
			returnToPreviousResultsButton.topAnchor.constraint(equalTo: navigationButtonGroup.topAnchor),
			returnToPreviousResultsButton.leadingAnchor.constraint(equalTo: navigationButtonGroup.leadingAnchor),
			returnToPreviousResultsButton.trailingAnchor.constraint(equalTo: navigationButtonGroup.trailingAnchor),

			refreshScanButton.topAnchor.constraint(equalTo: returnToPreviousResultsButton.bottomAnchor, constant: CloudKitStatsLayout.rowSpacing),
			refreshScanButton.leadingAnchor.constraint(equalTo: navigationButtonGroup.leadingAnchor),
			refreshScanButton.trailingAnchor.constraint(equalTo: navigationButtonGroup.trailingAnchor),
			refreshScanButton.bottomAnchor.constraint(equalTo: navigationButtonGroup.bottomAnchor)
		])
	}

	static func makeStatRow(_ title: String, valueLabel: NSTextField) -> NSView {
		let container = NSView()
		container.translatesAutoresizingMaskIntoConstraints = false

		let titleLabel = NSTextField(labelWithString: title)
		titleLabel.translatesAutoresizingMaskIntoConstraints = false

		valueLabel.translatesAutoresizingMaskIntoConstraints = false
		CloudKitStatsLayout.configureValueLabel(valueLabel)

		container.addSubview(titleLabel)
		container.addSubview(valueLabel)

		NSLayoutConstraint.activate([
			titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
			titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
			titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),

			valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
			valueLabel.lastBaselineAnchor.constraint(equalTo: titleLabel.lastBaselineAnchor)
		])

		return container
	}
}
