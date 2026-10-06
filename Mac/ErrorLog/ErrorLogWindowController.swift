//
//  ErrorLogWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/11/26.
//

import AppKit
import RSCore
import RSWeb
import Account
import ErrorLog

final class ErrorLogWindowController: NSWindowController, NSWindowDelegate {

	private static let windowIsOpenKey = "ErrorLogWindowIsOpen"

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
	private var hasLoadedEntries = false
	private var isLoadingEntries = false

	convenience init() {
		self.init(windowNibName: "ErrorLogWindow")
	}

	override func windowDidLoad() {
		super.windowDidLoad()
		window?.delegate = self

		textView?.usesFindBar = true
		textView?.font = NSFont.monospacedSystemFont(ofSize: LogTextStyle.fontSize, weight: .regular)
		textView?.textContainerInset = NSSize(width: LogTextStyle.textContainerInset, height: LogTextStyle.textContainerInset)

		updateCopyButtonState()

		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidEncounterError(_:)), name: .appDidEncounterError, object: nil)
	}

	override func showWindow(_ sender: Any?) {
		if !hasBeenShown {
			hasBeenShown = true
			window?.centerAboveCenter(by: LogTextStyle.aboveCenterOffset)
		}
		super.showWindow(sender)
		if !hasLoadedEntries && !isLoadingEntries {
			loadEntries()
		}
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

	@objc func handleAppDidEncounterError(_ notification: Notification) {
		guard let entry = ErrorLogEntry(notification: notification) else {
			return
		}
		Task { @MainActor in
			appendEntry(entry)
		}
	}

	// MARK: - Actions

	@IBAction func copyContents(_ sender: Any?) {
		textView?.copyAllToPasteboard()
	}

	@IBAction func showErrorLogHelp(_ sender: Any?) {
		if let url = URL(string: "https://netnewswire.com/help/error-log.html") {
			MacWebBrowser.openURL(url)
		}
	}
}

// MARK: - Private

private extension ErrorLogWindowController {

	/// Load recent entries from the on-disk error log database. Notifications that arrive while
	/// the load is in flight are dropped — they're already persisted by ErrorLogDatabase and will
	/// be loaded the next time this window opens.
	func loadEntries() {
		isLoadingEntries = true
		Task {
			let entries = await AccountManager.shared.errorLogDatabase.allEntries()
			defer {
				isLoadingEntries = false
				hasLoadedEntries = true
			}
			guard let textView else {
				return
			}
			let combined = NSMutableAttributedString()
			for entry in entries {
				combined.append(attributedString(for: entry))
			}
			textView.textStorage?.setAttributedString(combined)
			textView.scrollToEndOfDocument(nil)
			updateCopyButtonState()
		}
	}

	func appendEntry(_ entry: ErrorLogEntry) {
		guard hasLoadedEntries else {
			return
		}
		guard let textView, let textStorage = textView.textStorage else {
			return
		}

		let wasScrolledToBottom = textView.isScrolledToBottom
		textStorage.append(attributedString(for: entry))

		if wasScrolledToBottom {
			textView.scrollToEndOfDocument(nil)
		}
		updateCopyButtonState()
	}

	func updateCopyButtonState() {
		copyButton?.isEnabled = !(textView?.string.isEmpty ?? true)
	}

	func attributedString(for entry: ErrorLogEntry) -> NSAttributedString {
		let result = NSMutableAttributedString()

		let timestampString = "[\(DateFormatter.logTimestamp.string(from: entry.date))] "
		let timestampAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: NSColor.secondaryLabelColor,
			.font: NSFont.monospacedSystemFont(ofSize: LogTextStyle.fontSize, weight: .regular),
			.paragraphStyle: LogTextStyle.entryParagraphStyle
		]
		result.append(NSAttributedString(string: timestampString, attributes: timestampAttributes))

		let sourceNameString: String
		if entry.operation.isEmpty {
			sourceNameString = "\(entry.sourceName): "
		} else {
			sourceNameString = "\(entry.sourceName) — \(entry.operation): "
		}
		let sourceColor = AccountType(rawValue: entry.sourceID)?.logColor ?? .secondaryLabelColor
		let sourceAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: sourceColor,
			.font: NSFont.monospacedSystemFont(ofSize: LogTextStyle.fontSize, weight: .medium),
			.paragraphStyle: LogTextStyle.entryParagraphStyle
		]
		result.append(NSAttributedString(string: sourceNameString, attributes: sourceAttributes))

		let messageAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: NSColor.labelColor,
			.font: NSFont.monospacedSystemFont(ofSize: LogTextStyle.fontSize, weight: .regular),
			.paragraphStyle: LogTextStyle.entryParagraphStyle
		]
		result.append(NSAttributedString(string: entry.errorMessage, attributes: messageAttributes))

		if !entry.functionName.isEmpty {
			let locationString = " (\(entry.fileName):\(entry.functionName):\(entry.lineNumber))"
			let locationAttributes: [NSAttributedString.Key: Any] = [
				.foregroundColor: NSColor.tertiaryLabelColor,
				.font: NSFont.monospacedSystemFont(ofSize: LogTextStyle.fontSize, weight: .regular),
				.paragraphStyle: LogTextStyle.entryParagraphStyle
			]
			result.append(NSAttributedString(string: locationString, attributes: locationAttributes))
		}

		result.append(NSAttributedString(string: "\n", attributes: messageAttributes))

		return result
	}
}
