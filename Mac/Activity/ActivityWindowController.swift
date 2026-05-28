//
//  ActivityWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/4/26.
//

import AppKit
import Account
import ActivityLog

@MainActor final class ActivityWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {

	private static let windowIsOpenKey = "ActivityWindowIsOpen"
	private static let activityWindowAutosaveFrameName = "ActivityWindow"

	static private(set) var shouldOpenAtStartup: Bool {
		get {
			UserDefaults.standard.bool(forKey: windowIsOpenKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Self.windowIsOpenKey)
		}
	}

	private let tableView = NSTableView()
	private var hasBeenShown = false
	private var updateTimer: Timer?
	private var needsUpdate = false

	/// Activities currently displayed, including recently completed ones lingering.
	private var displayedActivities = [Activity]()

	/// Activities that completed/failed and are lingering before removal.
	private var lingeringActivities = [Activity: Timer]()

	private static let defaultWindowSize = NSSize(width: 500, height: 300)
	private static let minimumWindowSize = NSSize(width: 400, height: 200)
	private static let aboveCenterOffset: CGFloat = 40
	private static let updateCoalesceInterval: TimeInterval = 0.5
	private static let lingerDuration: TimeInterval = 5.0

	private static let ownerColumnID = NSUserInterfaceItemIdentifier("owner")
	private static let kindColumnID = NSUserInterfaceItemIdentifier("kind")
	private static let stateColumnID = NSUserInterfaceItemIdentifier("state")

	init() {
		let window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.defaultWindowSize), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: true)
		window.title = NSLocalizedString("Current Activity", comment: "Current Activity window title")
		window.minSize = Self.minimumWindowSize
		window.isReleasedWhenClosed = false

		super.init(window: window)
		setupUI()

		window.delegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(handleActivityDidChange(_:)), name: .activityDidChange, object: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not supported")
	}

	override func showWindow(_ sender: Any?) {
		if !hasBeenShown {
			hasBeenShown = true
			window?.center()
			if var frame = window?.frame {
				frame.origin.y += Self.aboveCenterOffset
				window?.setFrame(frame, display: false)
			}
			window?.setFrameAutosaveName(Self.activityWindowAutosaveFrameName)
		}
		super.showWindow(sender)
		scheduleUpdate()
	}

	func saveState() {
		Self.shouldOpenAtStartup = window?.isVisible ?? false
	}

	// MARK: - NSWindowDelegate

	func windowWillClose(_ notification: Notification) {
		updateTimer?.invalidate()
		updateTimer = nil
	}

	// MARK: - NSTableViewDataSource

	func numberOfRows(in tableView: NSTableView) -> Int {
		displayedActivities.count
	}

	// MARK: - NSTableViewDelegate

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard row < displayedActivities.count, let tableColumn else {
			return nil
		}

		let activity = displayedActivities[row]
		let cellIdentifier = tableColumn.identifier

		if cellIdentifier == Self.stateColumnID {
			return makeStateCellView(tableView: tableView, activity: activity)
		}

		if cellIdentifier == Self.kindColumnID {
			let cellView = makeCellView(tableView: tableView, identifier: cellIdentifier, text: "")
			cellView.textField?.attributedStringValue = attributedDisplayName(for: activity)
			return cellView
		}

		let text: String
		switch cellIdentifier {
		case Self.ownerColumnID:
			text = displayName(for: activity.owner)
		default:
			text = ""
		}

		return makeCellView(tableView: tableView, identifier: cellIdentifier, text: text)
	}

	// MARK: - Notifications

	@objc func handleActivityDidChange(_ notification: Notification) {
		scheduleUpdate()
	}
}

// MARK: - Private

private extension ActivityWindowController {

	func setupUI() {
		guard let contentView = window?.contentView else {
			return
		}

		let scrollView = NSScrollView()
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.hasVerticalScroller = true
		scrollView.autohidesScrollers = true
		scrollView.drawsBackground = true
		scrollView.documentView = tableView

		tableView.headerView = NSTableHeaderView()
		tableView.usesAlternatingRowBackgroundColors = true
		tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

		let ownerColumn = NSTableColumn(identifier: Self.ownerColumnID)
		ownerColumn.title = NSLocalizedString("Source", comment: "Activity window Source column")
		ownerColumn.width = 140
		ownerColumn.minWidth = 80

		let kindColumn = NSTableColumn(identifier: Self.kindColumnID)
		kindColumn.title = NSLocalizedString("Activity", comment: "Activity window Activity column")
		kindColumn.width = 220
		kindColumn.minWidth = 120

		let stateColumn = NSTableColumn(identifier: Self.stateColumnID)
		stateColumn.title = ""
		stateColumn.width = 24
		stateColumn.minWidth = 24
		stateColumn.maxWidth = 24

		tableView.addTableColumn(stateColumn)
		tableView.addTableColumn(ownerColumn)
		tableView.addTableColumn(kindColumn)

		tableView.dataSource = self
		tableView.delegate = self

		let separator = NSView()
		separator.translatesAutoresizingMaskIntoConstraints = false
		separator.wantsLayer = true
		separator.layer?.backgroundColor = NSColor(white: 0.75, alpha: 1.0).cgColor

		let bottomBar = NSVisualEffectView()
		bottomBar.translatesAutoresizingMaskIntoConstraints = false
		bottomBar.blendingMode = .withinWindow
		bottomBar.material = .titlebar

		let activityLogButton = NSButton(title: NSLocalizedString("Activity Log", comment: "Activity Log button"), target: nil, action: #selector(AppDelegate.showActivityLog(_:)))
		activityLogButton.translatesAutoresizingMaskIntoConstraints = false
		activityLogButton.controlSize = .large
		activityLogButton.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)

		let errorLogButton = NSButton(title: NSLocalizedString("Error Log", comment: "Error Log button"), target: nil, action: #selector(AppDelegate.showErrorLog(_:)))
		errorLogButton.translatesAutoresizingMaskIntoConstraints = false
		errorLogButton.controlSize = .large
		errorLogButton.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)

		bottomBar.addSubview(activityLogButton)
		bottomBar.addSubview(errorLogButton)

		contentView.addSubview(scrollView)
		contentView.addSubview(separator)
		contentView.addSubview(bottomBar)

		NSLayoutConstraint.activate([
			scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
			scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			scrollView.bottomAnchor.constraint(equalTo: separator.topAnchor),

			separator.heightAnchor.constraint(equalToConstant: 1),
			separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			separator.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

			activityLogButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
			activityLogButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

			errorLogButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
			errorLogButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
			errorLogButton.widthAnchor.constraint(equalTo: activityLogButton.widthAnchor),

			bottomBar.heightAnchor.constraint(equalToConstant: 44),
			bottomBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			bottomBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			bottomBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
		])
	}

	func scheduleUpdate() {
		guard window?.isVisible == true else {
			return
		}

		needsUpdate = true

		if updateTimer == nil {
			updateTimer = Timer.scheduledTimer(withTimeInterval: Self.updateCoalesceInterval, repeats: true) { [weak self] _ in
				Task { @MainActor in
					self?.coalescedUpdate()
				}
			}
		}
	}

	func coalescedUpdate() {
		guard needsUpdate else {
			if displayedActivities.isEmpty {
				updateTimer?.invalidate()
				updateTimer = nil
			}
			return
		}

		needsUpdate = false
		rebuildDisplayedActivities()
		tableView.reloadData()
	}

	func rebuildDisplayedActivities() {
		let manager = ActivityLog.shared

		var activities = [Activity]()
		activities.append(contentsOf: manager.runningActivities)
		activities.append(contentsOf: manager.pendingActivities)

		// Add recently completed/failed that are still lingering.
		for activity in manager.completedActivities {
			if lingeringActivities[activity] != nil {
				activities.append(activity)
			}
		}

		// Start linger timers for newly completed activities not already tracked.
		for activity in manager.completedActivities {
			if lingeringActivities[activity] == nil && isRecentlyCompleted(activity) {
				startLingerTimer(for: activity)
				if !activities.contains(where: { $0 === activity }) {
					activities.append(activity)
				}
			}
		}

		displayedActivities = activities
	}

	func isRecentlyCompleted(_ activity: Activity) -> Bool {
		guard let endDate = activity.endDate else {
			return false
		}
		return Date().timeIntervalSince(endDate) < Self.lingerDuration
	}

	func startLingerTimer(for activity: Activity) {
		let timer = Timer.scheduledTimer(withTimeInterval: Self.lingerDuration, repeats: false) { [weak self] _ in
			Task { @MainActor in
				self?.lingerTimerFired(for: activity)
			}
		}
		lingeringActivities[activity] = timer
	}

	func lingerTimerFired(for activity: Activity) {
		lingeringActivities.removeValue(forKey: activity)
		scheduleUpdate()
	}

	static let stateImageIdentifier = NSUserInterfaceItemIdentifier("stateImage")

	func makeStateCellView(tableView: NSTableView, activity: Activity) -> NSView {
		let cellView: NSTableCellView

		if let reused = tableView.makeView(withIdentifier: Self.stateImageIdentifier, owner: self) as? NSTableCellView {
			cellView = reused
		} else {
			cellView = NSTableCellView()
			cellView.identifier = Self.stateImageIdentifier
			let imageView = NSImageView()
			imageView.translatesAutoresizingMaskIntoConstraints = false
			imageView.imageScaling = .scaleProportionallyDown
			cellView.addSubview(imageView)
			cellView.imageView = imageView
			NSLayoutConstraint.activate([
				imageView.centerXAnchor.constraint(equalTo: cellView.centerXAnchor),
				imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
				imageView.widthAnchor.constraint(equalToConstant: 16),
				imageView.heightAnchor.constraint(equalToConstant: 16)
			])
		}

		switch activity.state {
		case .pending:
			let image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Pending")
			cellView.imageView?.image = image
			cellView.imageView?.contentTintColor = .tertiaryLabelColor
		case .running:
			let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Running")
			cellView.imageView?.image = image
			cellView.imageView?.contentTintColor = .systemBlue
		case .completed:
			let image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Completed")
			cellView.imageView?.image = image
			cellView.imageView?.contentTintColor = .systemGreen
		case .failed:
			let image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Failed")
			cellView.imageView?.image = image
			cellView.imageView?.contentTintColor = .systemRed
		}

		return cellView
	}

	func makeCellView(tableView: NSTableView, identifier: NSUserInterfaceItemIdentifier, text: String) -> NSTableCellView {
		let cellView: NSTableCellView

		if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
			cellView = reused
		} else {
			cellView = NSTableCellView()
			cellView.identifier = identifier
			let textField = NSTextField(labelWithString: "")
			textField.translatesAutoresizingMaskIntoConstraints = false
			textField.lineBreakMode = .byTruncatingTail
			textField.maximumNumberOfLines = 1
			cellView.addSubview(textField)
			cellView.textField = textField
			NSLayoutConstraint.activate([
				textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
				textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
				textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
			])
		}

		cellView.textField?.stringValue = text
		return cellView
	}

	func displayName(for owner: ActivityOwner) -> String {
		switch owner {
		case .app:
			return NSLocalizedString("NetNewsWire", comment: "Activity owner name")
		case .account(let accountID):
			return AccountManager.shared.existingAccount(accountID: accountID)?.nameForDisplay ?? accountID
		case .feedFinder:
			return NSLocalizedString("Feed Finder", comment: "Activity owner name")
		case .feedImageDownloader:
			return NSLocalizedString("Feed Images", comment: "Activity owner name")
		case .faviconDownloader:
			return NSLocalizedString("Favicons", comment: "Activity owner name")
		case .avatarDownloader:
			return NSLocalizedString("Avatars", comment: "Activity owner name")
		case .htmlMetadataDownloader:
			return NSLocalizedString("HTML Metadata", comment: "Activity owner name")
		}
	}

	func attributedDisplayName(for activity: Activity) -> NSAttributedString {
		let primaryAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: NSColor.labelColor
		]
		let secondaryAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: NSColor.secondaryLabelColor
		]

		switch activity.kind {
		case .refreshFeedContent(let feedURL):
			if let feedName = activity.detail {
				let result = NSMutableAttributedString(string: feedName, attributes: primaryAttributes)
				result.append(NSAttributedString(string: " \(feedURL)", attributes: secondaryAttributes))
				return result
			}
			return NSAttributedString(string: feedURL, attributes: primaryAttributes)
		case .findFeed(let urlString):
			let prefix = NSLocalizedString("Finding feed", comment: "Activity kind — finding a feed")
			let result = NSMutableAttributedString(string: "\(prefix) ", attributes: primaryAttributes)
			result.append(NSAttributedString(string: urlString, attributes: secondaryAttributes))
			return result
		case .downloadFeedImage(let feedURL):
			let prefix = NSLocalizedString("Downloading image", comment: "Activity kind — downloading feed image")
			let result = NSMutableAttributedString(string: "\(prefix) ", attributes: primaryAttributes)
			result.append(NSAttributedString(string: feedURL, attributes: secondaryAttributes))
			return result
		case .downloadFavicon(let faviconURL):
			let prefix = NSLocalizedString("Downloading favicon", comment: "Activity kind — downloading favicon")
			let result = NSMutableAttributedString(string: "\(prefix) ", attributes: primaryAttributes)
			result.append(NSAttributedString(string: faviconURL, attributes: secondaryAttributes))
			return result
		case .downloadAvatar(let avatarURL):
			let prefix = NSLocalizedString("Downloading avatar", comment: "Activity kind — downloading avatar")
			let result = NSMutableAttributedString(string: "\(prefix) ", attributes: primaryAttributes)
			result.append(NSAttributedString(string: avatarURL, attributes: secondaryAttributes))
			return result
		case .downloadHTMLMetadata(let urlString):
			let prefix = NSLocalizedString("Downloading metadata", comment: "Activity kind — downloading HTML metadata")
			let result = NSMutableAttributedString(string: "\(prefix) ", attributes: primaryAttributes)
			result.append(NSAttributedString(string: urlString, attributes: secondaryAttributes))
			return result
		default:
			let name = plainDisplayName(for: activity.kind)
			if let detail = activity.detail {
				let result = NSMutableAttributedString(string: name, attributes: primaryAttributes)
				result.append(NSAttributedString(string: " \(detail)", attributes: secondaryAttributes))
				return result
			}
			return NSAttributedString(string: name, attributes: primaryAttributes)
		}
	}

	func plainDisplayName(for kind: ActivityKind) -> String {
		switch kind {
		case .refreshAll:
			return NSLocalizedString("Refresh all", comment: "Activity kind")
		case .sendArticleStatuses:
			return NSLocalizedString("Sending statuses", comment: "Activity kind")
		case .refreshArticleStatuses:
			return NSLocalizedString("Refreshing statuses", comment: "Activity kind")
		case .refreshFeedList:
			return NSLocalizedString("Refreshing feed list", comment: "Activity kind")
		case .refreshMissingArticles:
			return NSLocalizedString("Refreshing missing articles", comment: "Activity kind")
		case .importOPML:
			return NSLocalizedString("Importing OPML", comment: "Activity kind")
		case .refreshFeedContent, .findFeed, .downloadFeedImage, .downloadFavicon, .downloadAvatar, .downloadHTMLMetadata:
			return ""
		}
	}

}
