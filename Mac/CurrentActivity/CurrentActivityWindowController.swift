//
//  CurrentActivityWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/4/26.
//

import AppKit
import Account
import ActivityLog
import RSWeb

@MainActor final class CurrentActivityWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {

	private static let windowIsOpenKey = "CurrentActivityWindowIsOpen"

	static private(set) var shouldOpenAtStartup: Bool {
		get {
			UserDefaults.standard.bool(forKey: windowIsOpenKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Self.windowIsOpenKey)
		}
	}

	@IBOutlet private var tableView: NSTableView?

	private var hasBeenShown = false
	private var updateTimer: Timer?
	private var needsUpdate = false
	private var displayedActivities = [Activity]()
	private var lingeringActivities = [Activity: Timer]()

	private static let aboveCenterOffset: CGFloat = 40
	private static let updateCoalesceInterval: TimeInterval = 0.5
	private static let lingerDuration: TimeInterval = 2.0

	convenience init() {
		self.init(windowNibName: "CurrentActivityWindow")
	}

	override func windowDidLoad() {
		super.windowDidLoad()
		window?.delegate = self
		NotificationCenter.default.addObserver(self, selector: #selector(handleActivityDidChange(_:)), name: .activityDidChange, object: nil)
	}

	override func showWindow(_ sender: Any?) {
		if !hasBeenShown {
			hasBeenShown = true
			window?.center()
			if var frame = window?.frame {
				frame.origin.y += Self.aboveCenterOffset
				window?.setFrame(frame, display: false)
			}
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
		guard let tableColumn, row < displayedActivities.count else {
			return nil
		}
		guard let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView else {
			return nil
		}
		let activity = displayedActivities[row]
		switch tableColumn.identifier.rawValue {
		case "source":
			cell.textField?.stringValue = activity.owner.displayName
			configureStateImage(cell, for: activity)
		case "activity":
			cell.textField?.attributedStringValue = attributedDisplayName(for: activity)
		default:
			break
		}
		return cell
	}

	// MARK: - Notifications

	@objc func handleActivityDidChange(_ notification: Notification) {
		scheduleUpdate()
	}

	// MARK: - Actions

	@IBAction func showHelp(_ sender: Any?) {
		if let url = URL(string: "https://netnewswire.com/help/current-activity.html") {
			MacWebBrowser.openURL(url)
		}
	}
}

// MARK: - Private

private extension CurrentActivityWindowController {

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
		tableView?.reloadData()
	}

	func rebuildDisplayedActivities() {
		let manager = ActivityLog.shared

		var activities = [Activity]()
		activities.append(contentsOf: manager.runningActivities)
		activities.append(contentsOf: manager.pendingActivities)

		for activity in manager.completedActivities {
			if lingeringActivities[activity] != nil {
				activities.append(activity)
			} else if isRecentlyCompleted(activity) {
				startLingerTimer(for: activity)
				activities.append(activity)
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

	func configureStateImage(_ cell: NSTableCellView, for activity: Activity) {
		let symbol: String
		let color: NSColor
		let label: String
		switch activity.state {
		case .pending:
			symbol = "circle"
			color = .tertiaryLabelColor
			label = "Pending"
		case .running:
			symbol = "circle.fill"
			color = .systemBlue
			label = "Running"
		case .completed:
			symbol = "checkmark.circle.fill"
			color = .systemGreen
			label = "Completed"
		case .failed:
			symbol = "xmark.circle.fill"
			color = .systemRed
			label = "Failed"
		}
		cell.imageView?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
		cell.imageView?.contentTintColor = color
	}

	func attributedDisplayName(for activity: Activity) -> NSAttributedString {
		switch activity.kind {
		case .refreshFeedContent(let feedURL):
			if let feedName = activity.detail {
				return attributedActivity(primary: feedName, secondary: feedURL)
			}
			return attributedActivity(primary: feedURL)
		case .findFeed(let urlString):
			return attributedActivity(primary: NSLocalizedString("Finding feed", comment: "Activity kind — finding a feed"), secondary: urlString)
		case .fetchFeedCandidate(let urlString):
			return attributedActivity(primary: NSLocalizedString("Fetching", comment: "Activity kind — fetching a candidate URL during feed finding"), secondary: urlString)
		case .downloadFeedImage(let feedURL):
			return attributedActivity(primary: NSLocalizedString("Downloading image", comment: "Activity kind — downloading feed image"), secondary: feedURL)
		case .downloadFavicon(let faviconURL):
			return attributedActivity(primary: NSLocalizedString("Downloading favicon", comment: "Activity kind — downloading favicon"), secondary: faviconURL)
		case .downloadAvatar(let avatarURL):
			return attributedActivity(primary: NSLocalizedString("Downloading avatar", comment: "Activity kind — downloading avatar"), secondary: avatarURL)
		case .downloadHTMLMetadata(let urlString):
			return attributedActivity(primary: NSLocalizedString("Downloading metadata", comment: "Activity kind — downloading HTML metadata"), secondary: urlString)
		default:
			return attributedActivity(primary: activity.kind.simpleDisplayName ?? "", secondary: activity.detail)
		}
	}

	/// Build a row label with optional secondary detail in secondary color. AppKit ignores
	/// `NSTextField.lineBreakMode` for `attributedStringValue`, so the truncating paragraph
	/// style rides along on the attributed string.
	func attributedActivity(primary: String, secondary: String? = nil) -> NSAttributedString {
		let paragraphStyle = NSMutableParagraphStyle()
		paragraphStyle.lineBreakMode = .byTruncatingTail
		let result = NSMutableAttributedString(string: primary, attributes: [
			.foregroundColor: NSColor.labelColor,
			.paragraphStyle: paragraphStyle
		])
		if let secondary {
			result.append(NSAttributedString(string: " \(secondary)", attributes: [
				.foregroundColor: NSColor.secondaryLabelColor,
				.paragraphStyle: paragraphStyle
			]))
		}
		return result
	}

}
