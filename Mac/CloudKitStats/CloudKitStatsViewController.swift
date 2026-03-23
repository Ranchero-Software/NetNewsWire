//
//  CloudKitStatsView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/20/26.
//

import AppKit
import Account
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

	// MARK: - Bottom bar views

	private let helpButton = NSButton()
	private let shareButton = NSButton()
	private let cleanUpButton = NSButton()

	// MARK: - Stats container

	private let statsContainerView = NSView()
	private var hasAppeared = false
	private var hasShownErrorAlert = false
	private var keyMonitor: Any?

	// MARK: - NSViewController

	override func loadView() {
		let containerView = NSView(frame: NSRect(origin: .zero, size: NSSize(width: Self.containerWidth, height: Self.containerWidth)))

		let statusBar = makeStatusBar()
		let topDivider = makeDivider()
		let statsSection = makeStatsSection()
		let bottomDivider = makeDivider()
		let bottomBarBackground = makeBarBackground()
		let bottomBar = makeBottomBar()

		containerView.addSubview(statusBar)
		containerView.addSubview(topDivider)
		containerView.addSubview(statsSection)
		containerView.addSubview(bottomDivider)
		containerView.addSubview(bottomBarBackground)
		containerView.addSubview(bottomBar)

		NSLayoutConstraint.activate([
			statusBar.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Self.sectionSpacing),
			statusBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Self.horizontalPadding),
			statusBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Self.horizontalPadding),

			topDivider.topAnchor.constraint(equalTo: statusBar.bottomAnchor, constant: Self.sectionSpacing),
			topDivider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			topDivider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

			statsSection.topAnchor.constraint(equalTo: topDivider.bottomAnchor, constant: Self.sectionSpacing),
			statsSection.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Self.horizontalPadding),
			statsSection.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Self.horizontalPadding),

			bottomDivider.topAnchor.constraint(equalTo: statsSection.bottomAnchor, constant: Self.sectionSpacing),
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

	func makeLabelWithIcon(_ text: String, symbolName: String, color: NSColor) -> NSView {
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
			icon.centerYAnchor.constraint(equalTo: label.centerYAnchor),
			icon.widthAnchor.constraint(equalToConstant: Self.iconSize),
			icon.heightAnchor.constraint(equalToConstant: Self.iconSize),
			icon.trailingAnchor.constraint(equalTo: container.trailingAnchor)
		])

		return container
	}

	func makeStatsSection() -> NSView {
		statsContainerView.translatesAutoresizingMaskIntoConstraints = false

		var constraints = [NSLayoutConstraint]()
		var previousAnchor = statsContainerView.topAnchor
		var previousSpacing: CGFloat = 0

		func addRow(_ labelView: NSView, _ valueLabel: NSTextField) {
			labelView.translatesAutoresizingMaskIntoConstraints = false
			valueLabel.translatesAutoresizingMaskIntoConstraints = false
			configureValueLabel(valueLabel)

			statsContainerView.addSubview(labelView)
			statsContainerView.addSubview(valueLabel)

			constraints.append(contentsOf: [
				labelView.topAnchor.constraint(equalTo: previousAnchor, constant: previousSpacing),
				labelView.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor),
				valueLabel.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor),
				valueLabel.lastBaselineAnchor.constraint(equalTo: labelView.lastBaselineAnchor)
			])

			previousAnchor = labelView.bottomAnchor
			previousSpacing = Self.rowSpacing
		}

		func addHeader(_ title: String) {
			let label = NSTextField(labelWithString: title)
			label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
			label.translatesAutoresizingMaskIntoConstraints = false

			statsContainerView.addSubview(label)

			constraints.append(contentsOf: [
				label.topAnchor.constraint(equalTo: previousAnchor, constant: previousSpacing),
				label.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor)
			])

			previousAnchor = label.bottomAnchor
			previousSpacing = Self.rowSpacing
		}

		func addSectionDivider() {
			let divider = makeDivider()
			statsContainerView.addSubview(divider)

			constraints.append(contentsOf: [
				divider.topAnchor.constraint(equalTo: previousAnchor, constant: Self.sectionSpacing),
				divider.leadingAnchor.constraint(equalTo: statsContainerView.leadingAnchor),
				divider.trailingAnchor.constraint(equalTo: statsContainerView.trailingAnchor)
			])

			previousAnchor = divider.bottomAnchor
			previousSpacing = Self.sectionSpacing
		}

		addHeader("Status Records")
		addRow(NSTextField(labelWithString: "Total"), statusRecordCountLabel)
		addRow(makeLabelWithIcon("Starred", symbolName: "star.fill", color: Self.starColor), starredCountLabel)
		addRow(makeLabelWithIcon("Unread", symbolName: "circle.fill", color: .controlAccentColor), unreadCountLabel)
		addRow(NSTextField(labelWithString: "Read"), readCountLabel)
		addRow(NSTextField(labelWithString: "Stale"), staleCountLabel)

		addSectionDivider()

		addHeader("Article Content Records")
		addRow(NSTextField(labelWithString: "Total"), totalContentCountLabel)
		addRow(makeLabelWithIcon("Starred", symbolName: "star.fill", color: Self.starColor), starredContentCountLabel)
		addRow(makeLabelWithIcon("Unread", symbolName: "circle.fill", color: .controlAccentColor), unreadContentCountLabel)
		addRow(NSTextField(labelWithString: "Read"), readContentCountLabel)
		addRow(NSTextField(labelWithString: "Orphaned"), orphanedContentCountLabel)

		constraints.append(previousAnchor.constraint(equalTo: statsContainerView.bottomAnchor))

		NSLayoutConstraint.activate(constraints)

		return statsContainerView
	}

	func configureValueLabel(_ label: NSTextField) {
		label.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
		label.alignment = .right
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
		NSAnimationContext.runAnimationGroup { context in
			context.duration = Self.animationDuration
			context.allowsImplicitAnimation = true

			updateStatusBar()
			updateStatsValues()
			updateBottomBar()
		}
	}

	func updateStatusBar() {
		switch model.fetchStatus {
		case .idle:
			break
		case .fetching:
			hasShownErrorAlert = false
			spinner.isHidden = false
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
			statusTextField.stringValue = "Scan failed."
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

	func updateStatsValues() {
		let stats = model.stats
		statusRecordCountLabel.stringValue = "\(stats.statusCount)"
		starredCountLabel.stringValue = "\(stats.starredStatusCount)"
		unreadCountLabel.stringValue = "\(stats.unreadStatusCount)"
		readCountLabel.stringValue = "\(stats.readStatusCount)"
		staleCountLabel.stringValue = "\(stats.staleStatusCount)"
		totalContentCountLabel.stringValue = "\(stats.articleCount)"
		starredContentCountLabel.stringValue = "\(stats.starredArticleCount)"
		unreadContentCountLabel.stringValue = "\(stats.unreadArticleCount)"
		readContentCountLabel.stringValue = "\(stats.readArticleCount)"
		orphanedContentCountLabel.stringValue = "\(stats.orphanedArticleCount)"

		statsContainerView.animator().alphaValue = model.fetchStatus.isFetching ? Self.fetchingAlpha : 1.0
	}

	func updateBottomBar() {
		shareButton.isEnabled = model.fetchStatus.isCompleted
		cleanUpButton.isEnabled = model.fetchStatus.isCompleted
	}

	func showErrorAlertIfNeeded() {
		guard let fetchError = model.fetchStatus.fetchError, !hasShownErrorAlert else {
			return
		}

		hasShownErrorAlert = true
		DispatchQueue.main.async {
			let alert = NSAlert()
			alert.alertStyle = .warning
			alert.messageText = "Couldn’t complete the iCloud scan because of an error:"
			alert.informativeText = fetchError.localizedDescription
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
		let picker = NSSharingServicePicker(items: [model.statsText])
		picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
	}

	@objc func cleanUpButtonPressed(_ sender: Any?) {
		// TODO: implement clean up
	}
}
