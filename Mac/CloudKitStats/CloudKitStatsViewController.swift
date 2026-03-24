//
//  CloudKitStatsViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/20/26.
//

import AppKit
import CloudKit
import Account
import CloudKitSync
import RSWeb

@MainActor final class CloudKitStatsViewController: NSViewController {

	private let model = CloudKitStatsViewModel()

	private static let escapeKeyCode: UInt16 = 53
	private static let containerWidth: CGFloat = 400
	private static let buttonWidth: CGFloat = 80
	private static let sectionSpacing: CGFloat = 14
	private static let horizontalPadding: CGFloat = 20
	private static let rowSpacing: CGFloat = 6
	private static let iconSize: CGFloat = 12
	private static let iconLabelGap: CGFloat = 4
	private static let spinnerTextGap: CGFloat = 6
	private static let buttonTextGap: CGFloat = 8
	private static let fetchingAlpha: CGFloat = 0.4
	private static let animationDuration: CGFloat = 0.25
	private static let starColor = NSColor(red: 0.976, green: 0.776, blue: 0.204, alpha: 1.0)

	// MARK: - Status bar views

	private let spinner = NSProgressIndicator()
	private let statusIcon = NSImageView()
	private let statusTextField = NSTextField(labelWithString: "")
	private let actionButton = NSButton()
	private var statusTextLeadingToSpinner: NSLayoutConstraint!
	private var statusTextLeadingToContainer: NSLayoutConstraint!

	// MARK: - Stats value labels

	private let statusRecordCountLabel = NSTextField(labelWithString: "0")
	private let starredCountLabel = NSTextField(labelWithString: "0")
	private let unreadCountLabel = NSTextField(labelWithString: "0")
	private let readCountLabel = NSTextField(labelWithString: "0")
	private let staleCountLabel = NSTextField(labelWithString: "0")
	private let totalContentCountLabel = NSTextField(labelWithString: "0")
	private let starredContentCountLabel = NSTextField(labelWithString: "0")
	private let unreadContentCountLabel = NSTextField(labelWithString: "0")
	private let readContentCountLabel = NSTextField(labelWithString: "0")
	private let orphanedContentCountLabel = NSTextField(labelWithString: "0")

	// MARK: - Cleanup views

	private let cleanUpContainerView = NSView()
	private let cleanUpProgressBar = NSProgressIndicator()
	private let cleanUpCancelButton = NSButton()
	private let cleanUpPhaseTextField = NSTextField(labelWithString: "")
	private let cleanUpErrorTextField = NSTextField(wrappingLabelWithString: "")
	private let cleanUpRefreshButton = NSButton()
	private let returnToPreviousResultsButton = NSButton()
	private let refreshScanButton = NSButton()
	private var cleanUpButtonGroup: NSView!

	private let staleStatusDeletedLabel = NSTextField(labelWithString: "0")
	private let readContentDeletedLabel = NSTextField(labelWithString: "0")
	private let unreadContentDeletedLabel = NSTextField(labelWithString: "0")
	private let orphanedContentDeletedLabel = NSTextField(labelWithString: "0")

	private var staleStatusDeletedRow: NSView!
	private var readContentDeletedRow: NSView!
	private var unreadContentDeletedRow: NSView!
	private var orphanedContentDeletedRow: NSView!

	// MARK: - Bottom bar views

	private let helpButton = NSButton()
	private let shareButton = NSButton()
	private let cleanUpButton = NSButton()

	// MARK: - Stats containers

	private let statsContainerView = NSView()
	private let statusSectionView = NSView()
	private let articleSectionView = NSView()
	private var hasAppeared = false
	private var hasShownErrorAlert = false
	private var keyMonitor: Any?

	// MARK: - Layout switching

	private var statusBarView: NSView!
	private var topDividerView: NSView!
	private var normalLayoutConstraints = [NSLayoutConstraint]()
	private var cleanUpLayoutConstraints = [NSLayoutConstraint]()
	private var isShowingCleanUp = false

	// MARK: - NSViewController

	override func loadView() {
		let containerView = NSView(frame: NSRect(origin: .zero, size: NSSize(width: Self.containerWidth, height: Self.containerWidth)))

		statusBarView = makeStatusBar()
		topDividerView = makeDivider()
		let statsSection = makeStatsSection()
		makeCleanUpSection()
		let bottomDivider = makeDivider()
		let bottomBarBackground = makeBarBackground()
		let bottomBar = makeBottomBar()

		containerView.addSubview(statusBarView)
		containerView.addSubview(topDividerView)
		containerView.addSubview(statsSection)
		containerView.addSubview(cleanUpContainerView)
		containerView.addSubview(bottomDivider)
		containerView.addSubview(bottomBarBackground)
		containerView.addSubview(bottomBar)

		cleanUpContainerView.isHidden = true

		normalLayoutConstraints = [
			statusBarView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Self.sectionSpacing),
			topDividerView.topAnchor.constraint(equalTo: statusBarView.bottomAnchor, constant: Self.sectionSpacing),
			statsSection.topAnchor.constraint(equalTo: topDividerView.bottomAnchor, constant: Self.sectionSpacing),
			bottomDivider.topAnchor.constraint(equalTo: statsSection.bottomAnchor, constant: Self.sectionSpacing)
		]

		cleanUpLayoutConstraints = [
			cleanUpContainerView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Self.sectionSpacing),
			bottomDivider.topAnchor.constraint(equalTo: cleanUpContainerView.bottomAnchor, constant: Self.sectionSpacing)
		]

		NSLayoutConstraint.activate([
			statusBarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Self.horizontalPadding),
			statusBarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Self.horizontalPadding),

			topDividerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			topDividerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

			statsSection.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Self.horizontalPadding),
			statsSection.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Self.horizontalPadding),

			cleanUpContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Self.horizontalPadding),
			cleanUpContainerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Self.horizontalPadding),

			bottomDivider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			bottomDivider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

			bottomBarBackground.topAnchor.constraint(equalTo: bottomDivider.bottomAnchor),
			bottomBarBackground.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			bottomBarBackground.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
			bottomBarBackground.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

			bottomBar.topAnchor.constraint(equalTo: bottomDivider.bottomAnchor, constant: Self.sectionSpacing),
			bottomBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Self.horizontalPadding),
			bottomBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Self.horizontalPadding),
			bottomBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Self.sectionSpacing)
		])

		NSLayoutConstraint.activate(normalLayoutConstraints)

		self.view = containerView
	}

	override func viewDidAppear() {
		super.viewDidAppear()

		model.onChange = { [weak self] in
			self?.updateUI()
		}

		if !hasAppeared {
			hasAppeared = true
			model.fetch()
		}
		updateUI()

		keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
			guard let self, self.view.window?.isKeyWindow == true else {
				return event
			}
			let isEscape = event.keyCode == Self.escapeKeyCode
			let isCmdPeriod = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command && event.charactersIgnoringModifiers == "."
			if (isEscape || isCmdPeriod) && self.model.fetchStatus.isFetching {
				self.model.cancelFetch()
				return nil
			}
			return event
		}
	}

	override func viewDidDisappear() {
		super.viewDidDisappear()
		if let keyMonitor {
			NSEvent.removeMonitor(keyMonitor)
		}
		keyMonitor = nil
	}
}

// MARK: - Private

private extension CloudKitStatsViewController {

	// MARK: - View Construction

	func makeStatusBar() -> NSView {
		let container = NSView()
		container.translatesAutoresizingMaskIntoConstraints = false

		spinner.style = .spinning
		spinner.controlSize = .small
		spinner.translatesAutoresizingMaskIntoConstraints = false
		spinner.startAnimation(nil)

		statusIcon.translatesAutoresizingMaskIntoConstraints = false
		statusIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Completed")
		statusIcon.contentTintColor = .systemGreen
		statusIcon.isHidden = true

		statusTextField.translatesAutoresizingMaskIntoConstraints = false
		statusTextField.textColor = .secondaryLabelColor
		statusTextField.font = .systemFont(ofSize: NSFont.systemFontSize)
		statusTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

		actionButton.translatesAutoresizingMaskIntoConstraints = false
		actionButton.bezelStyle = .rounded
		actionButton.title = "Cancel"
		actionButton.target = self
		actionButton.action = #selector(actionButtonPressed(_:))

		container.addSubview(spinner)
		container.addSubview(statusIcon)
		container.addSubview(statusTextField)
		container.addSubview(actionButton)

		statusTextLeadingToSpinner = statusTextField.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: Self.spinnerTextGap)
		statusTextLeadingToContainer = statusTextField.leadingAnchor.constraint(equalTo: container.leadingAnchor)

		NSLayoutConstraint.activate([
			spinner.leadingAnchor.constraint(equalTo: container.leadingAnchor),
			spinner.centerYAnchor.constraint(equalTo: statusTextField.centerYAnchor),

			statusIcon.leadingAnchor.constraint(equalTo: container.leadingAnchor),
			statusIcon.centerYAnchor.constraint(equalTo: statusTextField.centerYAnchor),

			statusTextLeadingToSpinner,

			actionButton.topAnchor.constraint(equalTo: container.topAnchor),
			actionButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
			statusTextField.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),

			actionButton.leadingAnchor.constraint(greaterThanOrEqualTo: statusTextField.trailingAnchor, constant: Self.buttonTextGap),
			actionButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
			actionButton.lastBaselineAnchor.constraint(equalTo: statusTextField.lastBaselineAnchor),
			actionButton.widthAnchor.constraint(equalToConstant: Self.buttonWidth)
		])

		return container
	}

	func makeBarBackground() -> NSVisualEffectView {
		let background = NSVisualEffectView()
		background.translatesAutoresizingMaskIntoConstraints = false
		background.blendingMode = .withinWindow
		background.material = .titlebar
		return background
	}

	func makeDivider() -> NSView {
		let divider = NSBox()
		divider.boxType = .separator
		divider.translatesAutoresizingMaskIntoConstraints = false
		return divider
	}

	func makeLabelWithIcon(_ text: String, symbolName: String, color: NSColor, iconOffset: CGFloat = 0) -> NSView {
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

			icon.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: Self.iconLabelGap),
			icon.centerYAnchor.constraint(equalTo: label.centerYAnchor, constant: iconOffset),
			icon.widthAnchor.constraint(equalToConstant: Self.iconSize),
			icon.heightAnchor.constraint(equalToConstant: Self.iconSize),
			icon.trailingAnchor.constraint(equalTo: container.trailingAnchor)
		])

		return container
	}

	func makeStatsSection() -> NSView {
		statsContainerView.translatesAutoresizingMaskIntoConstraints = false

		statusSectionView.translatesAutoresizingMaskIntoConstraints = false
		articleSectionView.translatesAutoresizingMaskIntoConstraints = false

		buildSectionRows(statusSectionView, rows: [
			("Status Records", nil),
			("Total", statusRecordCountLabel),
			(makeLabelWithIcon("Starred", symbolName: "star.fill", color: Self.starColor), starredCountLabel),
			(makeLabelWithIcon("Unread", symbolName: "circle.fill", color: .controlAccentColor, iconOffset: 0.5), unreadCountLabel),
			("Read", readCountLabel),
			("Stale", staleCountLabel)
		])

		buildSectionRows(articleSectionView, rows: [
			("Article Content Records", nil),
			("Total", totalContentCountLabel),
			(makeLabelWithIcon("Starred", symbolName: "star.fill", color: Self.starColor), starredContentCountLabel),
			(makeLabelWithIcon("Unread", symbolName: "circle.fill", color: .controlAccentColor, iconOffset: 0.5), unreadContentCountLabel),
			("Read", readContentCountLabel),
			("Orphaned", orphanedContentCountLabel)
		])

		let divider = makeDivider()

		statsContainerView.addSubview(statusSectionView)
		statsContainerView.addSubview(divider)
		statsContainerView.addSubview(articleSectionView)

		NSLayoutConstraint.activate([
			statusSectionView.topAnchor.constraint(equalTo: statsContainerView.topAnchor),
			statusSectionView.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor),
			statusSectionView.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor),

			divider.topAnchor.constraint(equalTo: statusSectionView.bottomAnchor, constant: Self.sectionSpacing),
			divider.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor),
			divider.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor),

			articleSectionView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: Self.sectionSpacing),
			articleSectionView.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor),
			articleSectionView.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor),
			articleSectionView.bottomAnchor.constraint(equalTo: statsContainerView.bottomAnchor)
		])

		return statsContainerView
	}

	func buildSectionRows(_ container: NSView, rows: [(Any, NSTextField?)]) {
		var constraints = [NSLayoutConstraint]()
		var previousAnchor = container.topAnchor
		var previousSpacing: CGFloat = 0
		var dataRowViews = [NSView]()

		for (label, valueLabel) in rows {
			if let valueLabel {
				// Data row
				let labelView: NSView
				if let string = label as? String {
					labelView = NSTextField(labelWithString: string)
				} else {
					labelView = label as! NSView
				}
				labelView.translatesAutoresizingMaskIntoConstraints = false
				valueLabel.translatesAutoresizingMaskIntoConstraints = false
				configureValueLabel(valueLabel)

				container.addSubview(labelView)
				container.addSubview(valueLabel)

				// For icon rows, the labelView is a container — find the
				// text field inside it so baseline alignment is correct.
				let baselineView: NSView
				if let textField = labelView as? NSTextField {
					baselineView = textField
				} else if let textField = labelView.subviews.compactMap({ $0 as? NSTextField }).first {
					baselineView = textField
				} else {
					baselineView = labelView
				}

				constraints.append(contentsOf: [
					labelView.topAnchor.constraint(equalTo: previousAnchor, constant: previousSpacing),
					labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
					valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
					valueLabel.lastBaselineAnchor.constraint(equalTo: baselineView.lastBaselineAnchor)
				])

				dataRowViews.append(labelView)
				previousAnchor = labelView.bottomAnchor
				previousSpacing = Self.rowSpacing
			} else {
				// Header row
				let title = label as! String
				let headerLabel = NSTextField(labelWithString: title)
				headerLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
				headerLabel.translatesAutoresizingMaskIntoConstraints = false

				container.addSubview(headerLabel)

				constraints.append(contentsOf: [
					headerLabel.topAnchor.constraint(equalTo: previousAnchor, constant: previousSpacing),
					headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor)
				])

				previousAnchor = headerLabel.bottomAnchor
				previousSpacing = Self.rowSpacing
			}
		}

		// Make all data rows the same height (tallest wins).
		if let firstRow = dataRowViews.first {
			for row in dataRowViews.dropFirst() {
				constraints.append(row.heightAnchor.constraint(equalTo: firstRow.heightAnchor))
			}
		}

		constraints.append(previousAnchor.constraint(equalTo: container.bottomAnchor))
		NSLayoutConstraint.activate(constraints)
	}

	func configureValueLabel(_ label: NSTextField) {
		label.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
		label.alignment = .right
	}

	func makeCleanUpSection() {
		cleanUpContainerView.translatesAutoresizingMaskIntoConstraints = false

		let stackView = NSStackView()
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.orientation = .vertical
		stackView.alignment = .leading
		stackView.spacing = Self.rowSpacing

		// Progress bar + Cancel button in a horizontal row
		let progressRow = NSView()
		progressRow.translatesAutoresizingMaskIntoConstraints = false

		cleanUpProgressBar.style = .bar
		cleanUpProgressBar.isIndeterminate = false
		cleanUpProgressBar.minValue = 0
		cleanUpProgressBar.maxValue = 1.0
		cleanUpProgressBar.doubleValue = 0
		cleanUpProgressBar.translatesAutoresizingMaskIntoConstraints = false

		cleanUpCancelButton.bezelStyle = .rounded
		cleanUpCancelButton.title = "Cancel"
		cleanUpCancelButton.translatesAutoresizingMaskIntoConstraints = false
		cleanUpCancelButton.target = self
		cleanUpCancelButton.action = #selector(cleanUpCancelButtonPressed(_:))
		cleanUpCancelButton.widthAnchor.constraint(equalToConstant: Self.buttonWidth).isActive = true

		progressRow.addSubview(cleanUpProgressBar)
		progressRow.addSubview(cleanUpCancelButton)

		NSLayoutConstraint.activate([
			cleanUpProgressBar.leadingAnchor.constraint(equalTo: progressRow.leadingAnchor),
			cleanUpProgressBar.centerYAnchor.constraint(equalTo: cleanUpCancelButton.centerYAnchor),
			cleanUpCancelButton.leadingAnchor.constraint(equalTo: cleanUpProgressBar.trailingAnchor, constant: Self.buttonTextGap),
			cleanUpCancelButton.trailingAnchor.constraint(equalTo: progressRow.trailingAnchor),
			cleanUpCancelButton.topAnchor.constraint(equalTo: progressRow.topAnchor),
			cleanUpCancelButton.bottomAnchor.constraint(equalTo: progressRow.bottomAnchor)
		])

		cleanUpPhaseTextField.textColor = .secondaryLabelColor
		cleanUpPhaseTextField.font = .systemFont(ofSize: NSFont.systemFontSize)

		staleStatusDeletedRow = makeCleanUpStatRow("Stale Status Deleted", valueLabel: staleStatusDeletedLabel)
		readContentDeletedRow = makeCleanUpStatRow("Read Content Deleted", valueLabel: readContentDeletedLabel)
		unreadContentDeletedRow = makeCleanUpStatRow("Unread Content Deleted", valueLabel: unreadContentDeletedLabel)
		orphanedContentDeletedRow = makeCleanUpStatRow("Orphaned Content Deleted", valueLabel: orphanedContentDeletedLabel)

		cleanUpErrorTextField.textColor = .secondaryLabelColor
		cleanUpErrorTextField.font = .systemFont(ofSize: NSFont.systemFontSize)
		cleanUpErrorTextField.isHidden = true

		cleanUpRefreshButton.bezelStyle = .rounded
		cleanUpRefreshButton.title = "Refresh"
		cleanUpRefreshButton.target = self
		cleanUpRefreshButton.action = #selector(refreshButtonPressed(_:))
		cleanUpRefreshButton.translatesAutoresizingMaskIntoConstraints = false
		cleanUpRefreshButton.isHidden = true

		stackView.addArrangedSubview(progressRow)
		stackView.addArrangedSubview(cleanUpPhaseTextField)
		stackView.addArrangedSubview(staleStatusDeletedRow)
		stackView.addArrangedSubview(readContentDeletedRow)
		stackView.addArrangedSubview(unreadContentDeletedRow)
		stackView.addArrangedSubview(orphanedContentDeletedRow)
		stackView.addArrangedSubview(cleanUpErrorTextField)
		stackView.addArrangedSubview(cleanUpRefreshButton)

		stackView.setCustomSpacing(Self.sectionSpacing, after: cleanUpPhaseTextField)

		// Navigation buttons pinned to the bottom, outside the stack view
		refreshScanButton.bezelStyle = .rounded
		refreshScanButton.title = "Refresh Scan"
		refreshScanButton.translatesAutoresizingMaskIntoConstraints = false
		refreshScanButton.target = self
		refreshScanButton.action = #selector(refreshButtonPressed(_:))
		returnToPreviousResultsButton.bezelStyle = .rounded
		returnToPreviousResultsButton.title = "Return to Previous Scan Results"
		returnToPreviousResultsButton.translatesAutoresizingMaskIntoConstraints = false
		returnToPreviousResultsButton.target = self
		returnToPreviousResultsButton.action = #selector(returnToPreviousResultsButtonPressed(_:))

		// Button group container for vertical centering
		cleanUpButtonGroup = NSView()
		cleanUpButtonGroup.translatesAutoresizingMaskIntoConstraints = false
		cleanUpButtonGroup.isHidden = true
		cleanUpButtonGroup.addSubview(returnToPreviousResultsButton)
		cleanUpButtonGroup.addSubview(refreshScanButton)

		NSLayoutConstraint.activate([
			returnToPreviousResultsButton.topAnchor.constraint(equalTo: cleanUpButtonGroup.topAnchor),
			returnToPreviousResultsButton.leadingAnchor.constraint(equalTo: cleanUpButtonGroup.leadingAnchor),
			returnToPreviousResultsButton.trailingAnchor.constraint(equalTo: cleanUpButtonGroup.trailingAnchor),

			refreshScanButton.topAnchor.constraint(equalTo: returnToPreviousResultsButton.bottomAnchor, constant: 8),
			refreshScanButton.leadingAnchor.constraint(equalTo: cleanUpButtonGroup.leadingAnchor),
			refreshScanButton.trailingAnchor.constraint(equalTo: cleanUpButtonGroup.trailingAnchor),
			refreshScanButton.bottomAnchor.constraint(equalTo: cleanUpButtonGroup.bottomAnchor)
		])

		cleanUpContainerView.addSubview(stackView)
		cleanUpContainerView.addSubview(cleanUpButtonGroup)

		// Layout guide for the space between the stack and the bottom edge
		let availableSpace = NSLayoutGuide()
		cleanUpContainerView.addLayoutGuide(availableSpace)

		NSLayoutConstraint.activate([
			stackView.topAnchor.constraint(equalTo: cleanUpContainerView.topAnchor),
			stackView.leadingAnchor.constraint(equalTo: cleanUpContainerView.leadingAnchor),
			stackView.trailingAnchor.constraint(equalTo: cleanUpContainerView.trailingAnchor),

			progressRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),

			staleStatusDeletedRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
			readContentDeletedRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
			unreadContentDeletedRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
			orphanedContentDeletedRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),

			cleanUpErrorTextField.widthAnchor.constraint(equalTo: stackView.widthAnchor),

			availableSpace.topAnchor.constraint(equalTo: stackView.bottomAnchor),
			availableSpace.bottomAnchor.constraint(equalTo: cleanUpContainerView.bottomAnchor),

			cleanUpButtonGroup.centerYAnchor.constraint(equalTo: availableSpace.centerYAnchor),
			cleanUpButtonGroup.centerXAnchor.constraint(equalTo: cleanUpContainerView.centerXAnchor)
		])
	}

	func makeCleanUpStatRow(_ title: String, valueLabel: NSTextField) -> NSView {
		let container = NSView()
		container.translatesAutoresizingMaskIntoConstraints = false

		let titleLabel = NSTextField(labelWithString: title)
		titleLabel.translatesAutoresizingMaskIntoConstraints = false

		valueLabel.translatesAutoresizingMaskIntoConstraints = false
		configureValueLabel(valueLabel)

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

	func makeBottomBar() -> NSView {
		let container = NSView()
		container.translatesAutoresizingMaskIntoConstraints = false

		helpButton.bezelStyle = .helpButton
		helpButton.title = ""
		helpButton.translatesAutoresizingMaskIntoConstraints = false
		helpButton.target = self
		helpButton.action = #selector(helpButtonPressed(_:))

		shareButton.bezelStyle = .rounded
		shareButton.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")
		shareButton.translatesAutoresizingMaskIntoConstraints = false
		shareButton.target = self
		shareButton.action = #selector(shareButtonPressed(_:))

		cleanUpButton.bezelStyle = .rounded
		cleanUpButton.title = "Clean Up"
		cleanUpButton.translatesAutoresizingMaskIntoConstraints = false
		cleanUpButton.target = self
		cleanUpButton.action = #selector(cleanUpButtonPressed(_:))

		container.addSubview(helpButton)
		container.addSubview(shareButton)
		container.addSubview(cleanUpButton)

		NSLayoutConstraint.activate([
			helpButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
			helpButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

			shareButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
			shareButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

			cleanUpButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
			cleanUpButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
			cleanUpButton.widthAnchor.constraint(equalToConstant: Self.buttonWidth),

			container.heightAnchor.constraint(equalTo: cleanUpButton.heightAnchor)
		])

		return container
	}

	// MARK: - UI Update

	func updateUI() {
		let isCleanUpActive = model.cleanUpStatus.isActive
		let needsTransition = isCleanUpActive != isShowingCleanUp

		if needsTransition {
			animateLayoutTransition(toCleanUp: isCleanUpActive)
		} else {
			NSAnimationContext.runAnimationGroup { context in
				context.duration = Self.animationDuration
				context.allowsImplicitAnimation = true

				if isCleanUpActive {
					updateCleanUpView()
				} else {
					updateStatusBar()
					updateStatsValues()
				}
				updateBottomBar()
			}
		}
	}

	func animateLayoutTransition(toCleanUp: Bool) {
		// Prepare incoming views: unhide at alpha 0 so they can fade in.
		if toCleanUp {
			cleanUpContainerView.alphaValue = 0
			cleanUpContainerView.isHidden = false
		} else {
			statusBarView.alphaValue = 0
			topDividerView.alphaValue = 0
			statsContainerView.alphaValue = 0
			statusBarView.isHidden = false
			topDividerView.isHidden = false
			statsContainerView.isHidden = false
		}

		NSAnimationContext.runAnimationGroup { context in
			context.duration = Self.animationDuration
			context.allowsImplicitAnimation = true

			if toCleanUp {
				isShowingCleanUp = true
				NSLayoutConstraint.deactivate(normalLayoutConstraints)
				NSLayoutConstraint.activate(cleanUpLayoutConstraints)
				statusBarView.animator().alphaValue = 0
				topDividerView.animator().alphaValue = 0
				statsContainerView.animator().alphaValue = 0
				cleanUpContainerView.animator().alphaValue = 1
				updateCleanUpView()
			} else {
				isShowingCleanUp = false
				NSLayoutConstraint.deactivate(cleanUpLayoutConstraints)
				NSLayoutConstraint.activate(normalLayoutConstraints)
				cleanUpContainerView.animator().alphaValue = 0
				statusBarView.animator().alphaValue = 1
				topDividerView.animator().alphaValue = 1
				statsContainerView.animator().alphaValue = 1
				updateStatusBar()
				updateStatsValues()
			}
			updateBottomBar()
		} completionHandler: { [weak self] in
			// Clean up: hide the faded-out views, reset their alpha for next transition.
			Task { @MainActor in
				guard let self else {
					return
				}
				if toCleanUp {
					self.statusBarView.isHidden = true
					self.topDividerView.isHidden = true
					self.statsContainerView.isHidden = true
					self.statusBarView.alphaValue = 1
					self.topDividerView.alphaValue = 1
					self.statsContainerView.alphaValue = 1
				} else {
					self.cleanUpContainerView.isHidden = true
					self.cleanUpContainerView.alphaValue = 1
					self.cleanUpProgressBar.doubleValue = 0
				}
			}
		}
	}

	func updateStatusBar() {
		switch model.fetchStatus {
		case .idle:
			break
		case .fetching:
			hasShownErrorAlert = false
			spinner.isHidden = false
			spinner.isIndeterminate = true
			spinner.style = .spinning
			spinner.startAnimation(nil)
			statusIcon.isHidden = true
			statusTextField.stringValue = "Scanning iCloud storage"
			actionButton.title = "Cancel"
			statusTextLeadingToSpinner.isActive = true
			statusTextLeadingToContainer.isActive = false
		case .completed:
			spinner.isHidden = true
			spinner.stopAnimation(nil)
			statusIcon.isHidden = false
			statusTextField.stringValue = "Scan completed."
			actionButton.title = "Refresh"
			statusTextLeadingToSpinner.isActive = true
			statusTextLeadingToContainer.isActive = false
		case .error:
			spinner.isHidden = true
			spinner.stopAnimation(nil)
			statusIcon.isHidden = true
			statusTextField.stringValue = "Scan failed. Numbers are incomplete."
			actionButton.title = "Refresh"
			statusTextLeadingToSpinner.isActive = false
			statusTextLeadingToContainer.isActive = true
			showErrorAlertIfNeeded()
		case .canceled:
			spinner.isHidden = true
			spinner.stopAnimation(nil)
			statusIcon.isHidden = true
			statusTextField.stringValue = "Canceled."
			actionButton.title = "Refresh"
			statusTextLeadingToSpinner.isActive = false
			statusTextLeadingToContainer.isActive = true
		}
	}

	func updateCleanUpView() {
		if model.cleanUpStatus.cleanUpError != nil {
			updateCleanUpViewForError()
			return
		}

		let isCanceled = model.cleanUpStatus.isCanceled

		guard let progress = model.cleanUpStatus.progress else {
			return
		}

		cleanUpErrorTextField.isHidden = true
		cleanUpRefreshButton.isHidden = true

		let plan = model.cleanUpPlan

		// Progress bar: visible during cleaning, hidden when canceled, visible at 100% when completed
		if isCanceled {
			cleanUpProgressBar.isHidden = true
			cleanUpCancelButton.isHidden = true
			cleanUpPhaseTextField.isHidden = false
			cleanUpPhaseTextField.stringValue = "Canceled."
		} else if model.cleanUpStatus.isCompleted {
			cleanUpProgressBar.isHidden = false
			cleanUpProgressBar.doubleValue = 1.0
			cleanUpCancelButton.isEnabled = false
			cleanUpPhaseTextField.isHidden = false
			cleanUpPhaseTextField.stringValue = cleanUpPhaseText(progress.phase)
		} else {
			cleanUpProgressBar.isHidden = false
			cleanUpCancelButton.isHidden = false
			cleanUpCancelButton.isEnabled = true
			cleanUpPhaseTextField.isHidden = false
			cleanUpPhaseTextField.stringValue = cleanUpPhaseText(progress.phase)
			if plan.totalCount > 0 {
				cleanUpProgressBar.doubleValue = Double(progress.totalDeleted) / Double(plan.totalCount)
			} else {
				cleanUpProgressBar.doubleValue = 0
			}
		}

		updateCleanUpStatRow(staleStatusDeletedRow, label: staleStatusDeletedLabel, value: progress.staleStatusDeleted, planned: plan.staleStatusCount)
		updateCleanUpStatRow(readContentDeletedRow, label: readContentDeletedLabel, value: progress.readContentDeleted, planned: plan.readContentCount)
		updateCleanUpStatRow(unreadContentDeletedRow, label: unreadContentDeletedLabel, value: progress.unreadContentDeleted, planned: plan.unreadContentCount)
		updateCleanUpStatRow(orphanedContentDeletedRow, label: orphanedContentDeletedLabel, value: progress.orphanedContentDeleted, planned: plan.orphanedContentCount)

		cleanUpButtonGroup.isHidden = !(isCanceled || model.cleanUpStatus.isCompleted)
	}

	func updateCleanUpViewForError() {
		cleanUpProgressBar.isHidden = true
		cleanUpCancelButton.isHidden = true
		cleanUpPhaseTextField.isHidden = true
		staleStatusDeletedRow.isHidden = true
		readContentDeletedRow.isHidden = true
		unreadContentDeletedRow.isHidden = true
		orphanedContentDeletedRow.isHidden = true
		cleanUpButtonGroup.isHidden = true
		cleanUpErrorTextField.isHidden = false
		cleanUpRefreshButton.isHidden = false
		cleanUpErrorTextField.stringValue = "Clean up failed to complete, but you may be able to clean up more if you wait a few minutes and try again.\n\nClick Refresh to see your updated stats."
	}

	func updateCleanUpStatRow(_ row: NSView, label: NSTextField, value: Int, planned: Int) {
		row.isHidden = planned == 0
		label.stringValue = formattedNumber(value)
	}

	func cleanUpPhaseText(_ phase: CloudKitCleanUpPhase) -> String {
		switch phase {
		case .deletingStaleStatus:
			return "Deleting stale status records…"
		case .deletingReadContent:
			return "Deleting read content records…"
		case .deletingUnreadContent:
			return "Deleting unread content records…"
		case .deletingOrphanedContent:
			return "Deleting orphaned content records…"
		case .completed:
			return "iCloud storage cleanup completed."
		}
	}

	func updateStatsValues() {
		let stats = model.stats
		statusRecordCountLabel.stringValue = formattedNumber(stats.statusCount)
		starredCountLabel.stringValue = formattedNumber(stats.starredStatusCount)
		unreadCountLabel.stringValue = formattedNumber(stats.unreadStatusCount)
		readCountLabel.stringValue = formattedNumber(stats.readStatusCount)
		staleCountLabel.stringValue = formattedNumber(stats.staleStatusCount)
		totalContentCountLabel.stringValue = formattedNumber(stats.articleCount)
		starredContentCountLabel.stringValue = formattedNumber(stats.starredArticleCount)
		unreadContentCountLabel.stringValue = formattedNumber(stats.unreadArticleCount)
		readContentCountLabel.stringValue = formattedNumber(stats.readArticleCount)
		orphanedContentCountLabel.stringValue = formattedNumber(stats.orphanedArticleCount)

		let isFetching = model.fetchStatus.isFetching
		let statusSectionDone = !isFetching || stats.articleCount > 0
		statusSectionView.animator().alphaValue = statusSectionDone ? 1.0 : Self.fetchingAlpha
		articleSectionView.animator().alphaValue = isFetching ? Self.fetchingAlpha : 1.0
	}

	func updateBottomBar() {
		let isCleaning = model.cleanUpStatus.isCleaning
		let isCleanUpDone = model.cleanUpStatus.isCompleted || model.cleanUpStatus.isCanceled || model.cleanUpStatus.cleanUpError != nil

		if isCleaning {
			cleanUpButton.isEnabled = false
			shareButton.isEnabled = true
		} else if isCleanUpDone {
			cleanUpButton.isEnabled = true
			shareButton.isEnabled = true
		} else {
			let enableShare = model.fetchStatus.isCompleted || model.fetchStatus.fetchError != nil
			shareButton.isEnabled = enableShare
			cleanUpButton.isEnabled = model.canCleanUp
		}
		actionButton.isEnabled = !isCleaning
	}

	func showErrorAlertIfNeeded() {
		guard let fetchError = model.fetchStatus.fetchError, !hasShownErrorAlert else {
			return
		}

		hasShownErrorAlert = true
		let displayError: Error
		if fetchError is CKError {
			displayError = CloudKitError(fetchError)
		} else {
			displayError = fetchError
		}
		DispatchQueue.main.async {
			let alert = NSAlert()
			alert.alertStyle = .warning
			alert.messageText = "Couldn't complete the iCloud scan because of an error:"
			alert.informativeText = displayError.localizedDescription
			alert.addButton(withTitle: "OK")
			alert.runModal()
		}
	}

	// MARK: - Actions

	@objc func actionButtonPressed(_ sender: Any?) {
		if model.fetchStatus.isFetching {
			model.cancelFetch()
		} else {
			model.fetch()
		}
	}

	@objc func helpButtonPressed(_ sender: Any?) {
		if let url = URL(string: "https://netnewswire.com/help/icloud.html") {
			MacWebBrowser.openURL(url)
		}
	}

	@objc func shareButtonPressed(_ sender: Any?) {
		guard let button = sender as? NSButton else {
			return
		}
		let text = model.cleanUpStatus.isActive ? model.cleanUpStatsText : model.statsText
		let picker = NSSharingServicePicker(items: [text])
		picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
	}

	@objc func cleanUpButtonPressed(_ sender: Any?) {
		let plan = model.cleanUpPlan
		guard !plan.isEmpty else {
			return
		}

		let alert = NSAlert()
		alert.alertStyle = .warning
		alert.messageText = "Clean Up iCloud Records"
		alert.informativeText = cleanUpConfirmationText(plan)
		alert.addButton(withTitle: "Clean Up")
		alert.addButton(withTitle: "Cancel")

		guard let window = view.window else {
			return
		}

		alert.beginSheetModal(for: window) { [weak self] response in
			guard response == .alertFirstButtonReturn else {
				return
			}
			self?.model.cleanUp()
		}
	}

	@objc func cleanUpCancelButtonPressed(_ sender: Any?) {
		model.cancelCleanUp()
	}

	@objc func refreshButtonPressed(_ sender: Any?) {
		model.fetch()
	}

	@objc func returnToPreviousResultsButtonPressed(_ sender: Any?) {
		model.cleanUpStatus = .idle
		updateUI()
	}

	func cleanUpConfirmationText(_ plan: CloudKitCleanUpPlan) -> String {
		var lines = [String]()
		if plan.staleStatusCount > 0 {
			lines.append(formattedCount(plan.staleStatusCount, singular: "stale status record", plural: "stale status records"))
		}
		if plan.readContentCount > 0 {
			lines.append(formattedCount(plan.readContentCount, singular: "read content record", plural: "read content records"))
		}
		if plan.unreadContentCount > 0 {
			lines.append(formattedCount(plan.unreadContentCount, singular: "unread content record", plural: "unread content records"))
		}
		if plan.orphanedContentCount > 0 {
			lines.append(formattedCount(plan.orphanedContentCount, singular: "orphaned content record", plural: "orphaned content records"))
		}
		let listText = lines.map { "• " + $0 }.joined(separator: "\n")
		return "This will delete:\n" + listText + "\n\nThis may take many minutes."
	}

	func formattedNumber(_ value: Int) -> String {
		NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
	}

	func formattedCount(_ count: Int, singular: String, plural: String) -> String {
		let label = count == 1 ? singular : plural
		return "\(formattedNumber(count)) \(label)"
	}
}
