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
	private var loggedCompletionIDs = Set<Int>()
	private var textEntryCount = 0
	private var needsRebuild = false

	private static let maxTextEntries = 1000

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
		formatter.locale = Locale(identifier: "en_US_POSIX")
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

		let combined = NSMutableAttributedString()
		for activity in ActivityLog.shared.completedActivities {
			combined.append(completionAttributedString(for: activity))
			loggedCompletionIDs.insert(activity.id)
			textEntryCount += 1
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

		let wasScrolledToBottom = isScrolledToBottom
		var didAppend = false

		for activity in ActivityLog.shared.completedActivities {
			guard !loggedCompletionIDs.contains(activity.id) else {
				continue
			}
			textView.textStorage?.append(completionAttributedString(for: activity))
			loggedCompletionIDs.insert(activity.id)
			textEntryCount += 1
			didAppend = true
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
		appendText("[\(Self.dateFormatter.string(from: date))] ", color: .secondaryLabelColor, to: result)

		let isFailed = activity.state == .failed
		let indicator = isFailed ? "✗ " : "✓ "
		appendText(indicator, color: isFailed ? .systemRed : .systemGreen, weight: .bold, to: result)

		let sourceColor = color(for: activity.owner)
		appendText("\(activity.owner.displayName): ", color: sourceColor, weight: .medium, to: result)
		appendText(plainDescription(for: activity), color: sourceColor, weight: .medium, to: result)

		if let detail = secondaryDetail(for: activity) {
			appendText(" \(detail)", color: .secondaryLabelColor, to: result)
		}

		if activity.durationIsSignificant, let startDate = activity.startDate, let endDate = activity.endDate {
			let duration = endDate.timeIntervalSince(startDate)
			appendText(" (\(formattedDuration(duration)))", color: .secondaryLabelColor, to: result)
		}

		// e.g. skip reason
		if let message = activity.completionMessage {
			appendText(" — \(message)", color: .secondaryLabelColor, to: result)
		}

		if isFailed, let error = activity.error {
			appendText(" — \(error.localizedDescription)", color: .systemRed, to: result)
		}

		appendText("\n", to: result)
		return result
	}

	func appendText(_ string: String, color: NSColor = .labelColor, weight: NSFont.Weight = .regular, to result: NSMutableAttributedString) {
		let attributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: color,
			.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: weight),
			.paragraphStyle: Self.entryParagraphStyle
		]
		result.append(NSAttributedString(string: string, attributes: attributes))
	}

	/// Feed-content activities show the URL as detail when the feed name is the primary text.
	func secondaryDetail(for activity: Activity) -> String? {
		switch activity.kind {
		case .refreshFeedContent(let feedURL):
			return activity.detail == nil ? nil : feedURL
		default:
			return activity.detail
		}
	}

	func formattedDuration(_ duration: TimeInterval) -> String {
		let posix = Locale(identifier: "en_US_POSIX")
		if duration < 10.0 {
			return String(format: "%.2fs", locale: posix, duration)
		} else if duration < 60.0 {
			return String(format: "%.1fs", locale: posix, duration)
		} else {
			let minutes = Int(duration) / 60
			let seconds = Int(duration) % 60
			return "\(minutes)m \(seconds)s"
		}
	}

	func plainDescription(for activity: Activity) -> String {
		switch activity.kind {
		case .refreshAll:
			return NSLocalizedString("Refresh all", comment: "Activity kind")
		case .sendArticleStatuses:
			return NSLocalizedString("Sending statuses", comment: "Activity kind")
		case .refreshArticleStatuses:
			return NSLocalizedString("Refreshing statuses", comment: "Activity kind")
		case .refreshFeedList:
			return NSLocalizedString("Refreshing feed list", comment: "Activity kind")
		case .refreshFeedContent(let feedURL):
			let format = NSLocalizedString("Refreshing feed: %@", comment: "Activity kind — refreshing a feed; %@ is the feed name or URL")
			return String(format: format, activity.detail ?? feedURL)
		case .refreshMissingArticles:
			return NSLocalizedString("Refreshing missing articles", comment: "Activity kind")
		case .importOPML:
			return NSLocalizedString("Importing OPML", comment: "Activity kind")
		case .findFeed(let urlString):
			let format = NSLocalizedString("Finding feed %@", comment: "Activity kind — finding a feed at %@ URL")
			return String(format: format, urlString)
		case .fetchFeedCandidate(let urlString):
			let format = NSLocalizedString("Fetching %@", comment: "Activity kind — fetching a candidate URL during feed finding")
			return String(format: format, urlString)
		case .downloadFeedImage(let feedURL):
			let format = NSLocalizedString("Downloading image %@", comment: "Activity kind — downloading a feed image; %@ is the URL")
			return String(format: format, feedURL)
		case .downloadFavicon(let faviconURL):
			let format = NSLocalizedString("Downloading favicon %@", comment: "Activity kind — downloading a favicon; %@ is the URL")
			return String(format: format, faviconURL)
		case .downloadAvatar(let avatarURL):
			let format = NSLocalizedString("Downloading avatar %@", comment: "Activity kind — downloading an author avatar; %@ is the URL")
			return String(format: format, avatarURL)
		case .downloadHTMLMetadata(let urlString):
			let format = NSLocalizedString("Downloading metadata %@", comment: "Activity kind — downloading HTML metadata; %@ is the URL")
			return String(format: format, urlString)
		case .subscribeFeed:
			return NSLocalizedString("Subscribing to feed", comment: "Activity kind")
		case .renameFeed:
			return NSLocalizedString("Renaming feed", comment: "Activity kind")
		case .removeFeed:
			return NSLocalizedString("Removing feed", comment: "Activity kind")
		case .moveFeed:
			return NSLocalizedString("Moving feed", comment: "Activity kind")
		case .addFeed:
			return NSLocalizedString("Adding feed", comment: "Activity kind")
		case .createFolder:
			return NSLocalizedString("Creating folder", comment: "Activity kind")
		case .renameFolder:
			return NSLocalizedString("Renaming folder", comment: "Activity kind")
		case .removeFolder:
			return NSLocalizedString("Removing folder", comment: "Activity kind")
		case .restoreFolder:
			return NSLocalizedString("Restoring folder", comment: "Activity kind")
		case .cleanUpCloudKitRecords:
			return NSLocalizedString("Cleaning up iCloud records", comment: "Activity kind")
		case .fetchCloudKitStats:
			return NSLocalizedString("Fetching iCloud stats", comment: "Activity kind")
		case .subscribeToCloudKitZone:
			return NSLocalizedString("Subscribing to zone changes", comment: "Activity kind")
		case .vacuumDatabase:
			return NSLocalizedString("Vacuuming database", comment: "Activity kind")
		case .validateCredentials:
			return NSLocalizedString("Validating credentials", comment: "Activity kind")
		case .exportOPML:
			return NSLocalizedString("Exporting OPML", comment: "Activity kind")
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
