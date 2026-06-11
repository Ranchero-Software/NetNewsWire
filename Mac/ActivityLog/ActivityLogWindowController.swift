//
//  ActivityLogWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/4/26.
//

import AppKit
import RSCore
import RSWeb
import Account
import ActivityLog

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

	@IBAction func showActivityLogHelp(_ sender: Any?) {
		if let url = URL(string: "https://netnewswire.com/help/activity-log.html") {
			MacWebBrowser.openURL(url)
		}
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
		for segment in ActivityLogViewModel.segments(for: activity) {
			appendText(segment.text, color: nsColor(for: segment.color), weight: fontWeight(for: segment.weight), to: result)
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

	func nsColor(for color: ActivityLogTextColor) -> NSColor {
		switch color {
		case .primary:
			return .labelColor
		case .secondary:
			return .secondaryLabelColor
		case .success:
			return .systemGreen
		case .failure:
			return .systemRed
		case .account(let accountID):
			guard let accountID, let account = AccountManager.shared.existingAccount(accountID: accountID) else {
				return .secondaryLabelColor
			}
			return account.type.logColor
		}
	}

	func fontWeight(for weight: ActivityLogTextWeight) -> NSFont.Weight {
		switch weight {
		case .regular:
			return .regular
		case .medium:
			return .medium
		case .bold:
			return .bold
		}
	}
}
