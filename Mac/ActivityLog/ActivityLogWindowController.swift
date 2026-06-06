//
//  ActivityLogWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/4/26.
//

import AppKit
import Account
import ActivityLog
import RSCore

final class ActivityLogWindowController: NSWindowController, NSWindowDelegate {

	private static let windowIsOpenKey = "ActivityLogWindowIsOpen"

	static private(set) var shouldOpenAtStartup: Bool {
		get {
			UserDefaults.standard.bool(forKey: windowIsOpenKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: windowIsOpenKey)
		}
	}

	@IBOutlet private var textView: NSTextView?
	@IBOutlet private var copyButton: NSButton?

	private var hasBeenShown = false
	private var loggedCompletionIDs = Set<Int>()
	private var textEntryCount = 0
	private var needsRebuild = false

	private static let maxTextEntries = 1000

	convenience init() {
		self.init(windowNibName: "ActivityLogWindow")
	}

	override func windowDidLoad() {
		super.windowDidLoad()
		window?.delegate = self

		textView?.usesFindBar = true
		textView?.font = NSFont.monospacedSystemFont(ofSize: LogTextStyle.fontSize, weight: .regular)
		textView?.textContainerInset = NSSize(width: LogTextStyle.textContainerInset, height: LogTextStyle.textContainerInset)

		updateCopyButtonState()

		NotificationCenter.default.addObserver(self, selector: #selector(handleActivityDidChange(_:)), name: .activityDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleWindowDidResignMain(_:)), name: NSWindow.didResignMainNotification, object: window)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidResignActive(_:)), name: NSApplication.didResignActiveNotification, object: nil)
	}

	override func showWindow(_ sender: Any?) {
		if !hasBeenShown {
			hasBeenShown = true
			window?.centerAboveCenter(by: LogTextStyle.aboveCenterOffset)
		}
		super.showWindow(sender)
		reloadEntries()
	}

	@IBAction override func performTextFinderAction(_ sender: Any?) {
		textView?.performTextFinderAction(sender)
	}

	func saveState() {
		Self.shouldOpenAtStartup = window?.isVisible ?? false
	}

	// MARK: - NSWindowDelegate

	func windowDidResize(_ notification: Notification) {
		textView?.updateContainerSizeForLiveResize()
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
		textView?.copyAllToPasteboard()
	}
}

// MARK: - Private

private extension ActivityLogWindowController {

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

		let wasScrolledToBottom = textView.isScrolledToBottom
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

	// MARK: - Attributed Strings

	func completionAttributedString(for activity: Activity) -> NSAttributedString {
		let result = NSMutableAttributedString()

		let date = activity.endDate ?? Date()
		appendText("[\(DateFormatter.logTimestamp.string(from: date))] ", color: .secondaryLabelColor, to: result)

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
			.font: NSFont.monospacedSystemFont(ofSize: LogTextStyle.fontSize, weight: weight),
			.paragraphStyle: LogTextStyle.entryParagraphStyle
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
		if let simple = activity.kind.simpleDisplayName {
			return simple
		}
		switch activity.kind {
		case .refreshFeedContent(let feedURL):
			let format = NSLocalizedString("Refreshing feed: %@", comment: "Activity kind — refreshing a feed; %@ is the feed name or URL")
			return String(format: format, activity.detail ?? feedURL)
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
		default:
			return ""
		}
	}

	func color(for owner: ActivityOwner) -> NSColor {
		switch owner {
		case .account(let accountID, _):
			guard let account = AccountManager.shared.existingAccount(accountID: accountID) else {
				return .secondaryLabelColor
			}
			return account.type.logColor
		case .app, .feedFinder, .feedImageDownloader, .faviconDownloader, .avatarDownloader, .htmlMetadataDownloader:
			return .secondaryLabelColor
		}
	}
}
