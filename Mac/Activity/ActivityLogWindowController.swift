//
//  ActivityLogWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/4/26.
//

import AppKit
import Account
import ActivityLog

final class ActivityLogWindowController: NSWindowController, NSWindowDelegate {

	private static let windowIsOpenKey = "ActivityLogWindowIsOpen"

	static private(set) var shouldOpenAtStartup: Bool {
		get {
			UserDefaults.standard.bool(forKey: windowIsOpenKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Self.windowIsOpenKey)
		}
	}

	@IBOutlet private var textView: NSTextView?
	@IBOutlet private var copyButton: NSButton?

	private var hasBeenShown = false

	/// Activity IDs for which we've logged the completion entry.
	private var loggedCompletionIDs = Set<Int>()
	/// Number of text entries appended to the text view.
	private var textEntryCount = 0
	/// Maximum text entries before rebuilding.
	private static let maxTextEntries = 1000

	private var needsRebuild = false

	private static let aboveCenterOffset: CGFloat = 40

	convenience init() {
		self.init(windowNibName: "ActivityLogWindow")
	}

	override func windowDidLoad() {
		super.windowDidLoad()
		window?.delegate = self

		textView?.font = NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular)
		textView?.textContainerInset = NSSize(width: Self.textContainerInset, height: Self.textContainerInset)

		updateCopyButtonState()

		NotificationCenter.default.addObserver(self, selector: #selector(handleActivityDidChange(_:)), name: .activityDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleWindowDidResignMain(_:)), name: NSWindow.didResignMainNotification, object: window)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidResignActive(_:)), name: NSApplication.didResignActiveNotification, object: nil)
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
		reloadEntries()
	}

	func saveState() {
		Self.shouldOpenAtStartup = window?.isVisible ?? false
	}

	// MARK: - NSWindowDelegate

	func windowDidResize(_ notification: Notification) {
		guard let textView, let container = textView.textContainer else {
			return
		}
		container.size = NSSize(width: textView.bounds.width - textView.textContainerInset.width * 2, height: CGFloat.greatestFiniteMagnitude)
		textView.layoutManager?.ensureLayout(for: container)
	}

	// MARK: - Notifications

	@objc func handleActivityDidChange(_ notification: Notification) {
		guard window?.isVisible == true else {
			return
		}
		appendNewEntries()
	}

	@objc func handleWindowDidResignMain(_ notification: Notification) {
		rebuildIfNeeded()
	}

	@objc func handleAppDidResignActive(_ notification: Notification) {
		rebuildIfNeeded()
	}

	// MARK: - Actions

	@IBAction func copyContents(_ sender: Any?) {
		guard let text = textView?.string, !text.isEmpty else {
			return
		}
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(text, forType: .string)
	}
}

// MARK: - Private

private extension ActivityLogWindowController {

	static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		return formatter
	}()

	static let fontSize: CGFloat = 16.0
	static let textContainerInset: CGFloat = 8
	static let lineSpacing: CGFloat = 4
	static let paragraphSpacing: CGFloat = 7
	static let entryParagraphStyle: NSParagraphStyle = {
		let style = NSMutableParagraphStyle()
		style.lineSpacing = lineSpacing
		style.paragraphSpacing = paragraphSpacing
		return style
	}()

	func rebuildIfNeeded() {
		guard needsRebuild else {
			return
		}
		needsRebuild = false
		reloadEntries()
	}

	func reloadEntries() {
		guard let textView else {
			return
		}
		loggedCompletionIDs.removeAll()
		textEntryCount = 0

		let activityLog = ActivityLog.shared
		let allActivities = activityLog.runningActivities + activityLog.completedActivities

		let combined = NSMutableAttributedString()
		for activity in allActivities {
			if activity.state == .completed || activity.state == .failed {
				combined.append(completionAttributedString(for: activity))
				loggedCompletionIDs.insert(activity.id)
				textEntryCount += 1
			}
		}

		textView.textStorage?.setAttributedString(combined)
		textView.scrollToEndOfDocument(nil)
		updateCopyButtonState()
	}

	func appendNewEntries() {
		guard let textView else {
			return
		}
		if textEntryCount > Self.maxTextEntries {
			needsRebuild = true
		}

		let activityLog = ActivityLog.shared
		let allActivities = activityLog.runningActivities + activityLog.completedActivities

		let wasScrolledToBottom = isScrolledToBottom
		var didAppend = false

		for activity in allActivities {
			let isFinished = activity.state == .completed || activity.state == .failed
			if isFinished && !loggedCompletionIDs.contains(activity.id) {
				textView.textStorage?.append(completionAttributedString(for: activity))
				loggedCompletionIDs.insert(activity.id)
				textEntryCount += 1
				didAppend = true
			}
		}

		if didAppend {
			if wasScrolledToBottom {
				textView.scrollToEndOfDocument(nil)
			}
			updateCopyButtonState()
		}
	}

	func updateCopyButtonState() {
		copyButton?.isEnabled = !(textView?.string.isEmpty ?? true)
	}

	var isScrolledToBottom: Bool {
		guard let textView, let scrollView = textView.enclosingScrollView else {
			return true
		}
		let contentView = scrollView.contentView
		let visibleMaxY = contentView.bounds.maxY
		let documentMaxY = textView.frame.maxY
		return visibleMaxY >= documentMaxY - 1
	}

	// MARK: - Attributed Strings

	func completionAttributedString(for activity: Activity) -> NSAttributedString {
		let result = NSMutableAttributedString()

		let date = activity.endDate ?? Date()
		appendTimestamp(date, to: result)

		let isFailed = activity.state == .failed
		let indicator = isFailed ? "✗ " : "✓ "
		let indicatorColor: NSColor = isFailed ? .systemRed : .systemGreen
		let indicatorAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: indicatorColor,
			.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .bold),
			.paragraphStyle: Self.entryParagraphStyle
		]
		result.append(NSAttributedString(string: indicator, attributes: indicatorAttributes))

		appendSource(for: activity, to: result)
		appendKindAndDetail(for: activity, to: result)

		// Duration
		if activity.durationIsSignificant, let startDate = activity.startDate, let endDate = activity.endDate {
			let duration = endDate.timeIntervalSince(startDate)
			let durationText = " (\(formattedDuration(duration)))"
			let durationAttributes: [NSAttributedString.Key: Any] = [
				.foregroundColor: NSColor.secondaryLabelColor,
				.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular),
				.paragraphStyle: Self.entryParagraphStyle
			]
			result.append(NSAttributedString(string: durationText, attributes: durationAttributes))
		}

		// Completion message (e.g. skip reason)
		if let message = activity.completionMessage {
			let messageAttributes: [NSAttributedString.Key: Any] = [
				.foregroundColor: NSColor.secondaryLabelColor,
				.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular),
				.paragraphStyle: Self.entryParagraphStyle
			]
			result.append(NSAttributedString(string: " — \(message)", attributes: messageAttributes))
		}

		// Error
		if isFailed, let error = activity.error {
			let errorAttributes: [NSAttributedString.Key: Any] = [
				.foregroundColor: NSColor.systemRed,
				.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular),
				.paragraphStyle: Self.entryParagraphStyle
			]
			result.append(NSAttributedString(string: " — \(error.localizedDescription)", attributes: errorAttributes))
		}

		appendNewline(to: result)

		return result
	}

	func appendTimestamp(_ date: Date, to result: NSMutableAttributedString) {
		let timestampString = "[\(Self.dateFormatter.string(from: date))] "
		let timestampAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: NSColor.secondaryLabelColor,
			.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular),
			.paragraphStyle: Self.entryParagraphStyle
		]
		result.append(NSAttributedString(string: timestampString, attributes: timestampAttributes))
	}

	func appendSource(for activity: Activity, to result: NSMutableAttributedString) {
		let sourceName = displayName(for: activity.owner)
		let sourceColor = color(for: activity.owner)
		let sourceAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: sourceColor,
			.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .medium),
			.paragraphStyle: Self.entryParagraphStyle
		]
		result.append(NSAttributedString(string: "\(sourceName): ", attributes: sourceAttributes))
	}

	func appendKindAndDetail(for activity: Activity, to result: NSMutableAttributedString) {
		let sourceColor = color(for: activity.owner)
		let messageAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: sourceColor,
			.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .medium),
			.paragraphStyle: Self.entryParagraphStyle
		]
		result.append(NSAttributedString(string: plainDescription(for: activity), attributes: messageAttributes))

		let secondaryText = secondaryDetail(for: activity)
		if !secondaryText.isEmpty {
			let detailAttributes: [NSAttributedString.Key: Any] = [
				.foregroundColor: NSColor.secondaryLabelColor,
				.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular),
				.paragraphStyle: Self.entryParagraphStyle
			]
			result.append(NSAttributedString(string: " \(secondaryText)", attributes: detailAttributes))
		}
	}

	/// Returns secondary detail text for the log entry.
	/// For feed content activities with a name, shows the URL; otherwise shows the detail string.
	func secondaryDetail(for activity: Activity) -> String {
		switch activity.kind {
		case .refreshFeedContent(let feedURL):
			if activity.detail != nil {
				return feedURL
			}
			return ""
		default:
			return activity.detail ?? ""
		}
	}

	func appendNewline(to result: NSMutableAttributedString) {
		let attributes: [NSAttributedString.Key: Any] = [
			.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular),
			.paragraphStyle: Self.entryParagraphStyle
		]
		result.append(NSAttributedString(string: "\n", attributes: attributes))
	}

	func formattedDuration(_ duration: TimeInterval) -> String {
		if duration < 10.0 {
			return String(format: "%.2fs", duration)
		} else if duration < 60.0 {
			return String(format: "%.1fs", duration)
		} else {
			let minutes = Int(duration) / 60
			let seconds = Int(duration) % 60
			return "\(minutes)m \(seconds)s"
		}
	}

	func displayName(for owner: ActivityOwner) -> String {
		switch owner {
		case .app:
			return "NetNewsWire"
		case .account(let accountID):
			return AccountManager.shared.existingAccount(accountID: accountID)?.nameForDisplay ?? accountID
		case .feedFinder:
			return "Feed Finder"
		case .feedImageDownloader:
			return "Feed Images"
		case .faviconDownloader:
			return "Favicons"
		case .avatarDownloader:
			return "Avatars"
		case .htmlMetadataDownloader:
			return "HTML Metadata"
		}
	}

	func plainDescription(for activity: Activity) -> String {
		switch activity.kind {
		case .refreshAll:
			return "Refresh all"
		case .sendArticleStatuses:
			return "Sending statuses"
		case .refreshArticleStatuses:
			return "Refreshing statuses"
		case .refreshFeedList:
			return "Refreshing feed list"
		case .refreshFeedContent(let feedURL):
			if let feedName = activity.detail {
				return "Refreshing feed: \(feedName)"
			}
			return "Refreshing feed: \(feedURL)"
		case .refreshMissingArticles:
			return "Refreshing missing articles"
		case .importOPML:
			return "Importing OPML"
		case .findFeed(let urlString):
			return "Finding feed \(urlString)"
		case .fetchFeedCandidate(let urlString):
			return "Fetching \(urlString)"
		case .downloadFeedImage(let feedURL):
			return "Downloading image \(feedURL)"
		case .downloadFavicon(let faviconURL):
			return "Downloading favicon \(faviconURL)"
		case .downloadAvatar(let avatarURL):
			return "Downloading avatar \(avatarURL)"
		case .downloadHTMLMetadata(let urlString):
			return "Downloading metadata \(urlString)"
		case .subscribeFeed:
			return "Subscribing to feed"
		case .renameFeed:
			return "Renaming feed"
		case .removeFeed:
			return "Removing feed"
		case .moveFeed:
			return "Moving feed"
		case .addFeed:
			return "Adding feed"
		case .createFolder:
			return "Creating folder"
		case .renameFolder:
			return "Renaming folder"
		case .removeFolder:
			return "Removing folder"
		case .restoreFolder:
			return "Restoring folder"
		case .cleanUpCloudKitRecords:
			return "Cleaning up iCloud records"
		case .fetchCloudKitStats:
			return "Fetching iCloud stats"
		case .subscribeToCloudKitZone:
			return "Subscribing to zone changes"
		case .vacuumDatabase:
			return "Vacuuming database"
		case .validateCredentials:
			return "Validating credentials"
		case .exportOPML:
			return "Exporting OPML"
		}
	}

	func color(for owner: ActivityOwner) -> NSColor {
		switch owner {
		case .account(let accountID):
			guard let account = AccountManager.shared.existingAccount(accountID: accountID) else {
				return .secondaryLabelColor
			}
			return account.type.logColor
		case .app, .feedFinder, .feedImageDownloader, .faviconDownloader, .avatarDownloader, .htmlMetadataDownloader:
			return .secondaryLabelColor
		}
	}
}
