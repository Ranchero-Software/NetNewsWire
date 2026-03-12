//
//  ErrorLogWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/11/26.
//

import AppKit
import Account

@MainActor final class ErrorLogWindowController: NSWindowController, NSWindowDelegate {

	private static let windowIsOpenKey = "ErrorLogWindowIsOpen"
	private static let windowHasBeenShownKey = "ErrorLogWindowHasBeenShown"
	private static let errorLogWindowAutosaveFrameName = "ErrorLogWindow"

	static private(set) var shouldOpenAtStartup: Bool {
		get {
			UserDefaults.standard.bool(forKey: windowIsOpenKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Self.windowIsOpenKey)
		}
	}

	private static var hasBeenShownBefore: Bool {
		get {
			UserDefaults.standard.bool(forKey: windowHasBeenShownKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: windowHasBeenShownKey)
		}
	}

	private var textView = NSTextView()
	private var copyButton: NSButton?
	private var hasBeenShown = false
	private var hasLoadedEntries = false

	private static let defaultWindowSize = NSSize(width: 600, height: 400)

	init() {
		let window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.defaultWindowSize), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: true)
		window.title = NSLocalizedString("Errors", comment: "Errors window title")
		window.minSize = Self.minimumWindowSize
		window.isReleasedWhenClosed = false
		window.setFrameAutosaveName(Self.errorLogWindowAutosaveFrameName)

		super.init(window: window)
		setupUI()

		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountDidEncounterSyncError(_:)), name: .AccountDidEncounterSyncError, object: nil)

		window.delegate = self
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) is not supported")
	}

	override func showWindow(_ sender: Any?) {
		if !hasBeenShown {
			hasBeenShown = true
			if !Self.hasBeenShownBefore {
				Self.hasBeenShownBefore = true
				window?.center()
				var frame = window?.frame ?? .zero
				frame.origin.y += Self.firstShowVerticalOffset
				window?.setFrame(frame, display: false)
			}
		}
		super.showWindow(sender)
		if !hasLoadedEntries {
			hasLoadedEntries = true
			loadEntries()
		}
	}

	func saveState() {
		Self.shouldOpenAtStartup = window?.isVisible ?? false
	}

	// MARK: - NSWindowDelegate

	func windowDidResize(_ notification: Notification) {
		// Make the NSTextView resize during live resize.
		guard let container = textView.textContainer else {
			return
		}
		container.size = NSSize(width: textView.bounds.width - textView.textContainerInset.width * 2, height: CGFloat.greatestFiniteMagnitude)
		textView.layoutManager?.ensureLayout(for: container)
	}

	// MARK: - Notifications

	@objc func handleAccountDidEncounterSyncError(_ notification: Notification) {
		guard let error = notification.userInfo?[Account.UserInfoKey.syncError] as? Error,
			  let accountName = notification.userInfo?[Account.UserInfoKey.accountName] as? String,
			  let accountType = notification.userInfo?[Account.UserInfoKey.accountType] as? Int else {
			return
		}

		let entry = ErrorLogEntry(id: 0, timestamp: Date(), accountName: accountName, accountType: accountType, errorMessage: error.localizedDescription)
		appendEntry(entry)
	}
}

// MARK: - Private

private extension ErrorLogWindowController {

	static let minimumWindowSize = NSSize(width: 400, height: 300)
	static let firstShowVerticalOffset: CGFloat = 40
	static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		return formatter
	}()

	static let fontSize: CGFloat = 16.0
	static let textContainerInset: CGFloat = 8
	static let separatorHeight: CGFloat = 1
	static let separatorWhite: CGFloat = 0.75
	static let bottomBarHeight: CGFloat = 52
	static let bottomBarPadding: CGFloat = 16
	static let lineSpacing: CGFloat = 4
	static let paragraphSpacing: CGFloat = 7
	static let entryParagraphStyle: NSParagraphStyle = {
		let style = NSMutableParagraphStyle()
		style.lineSpacing = lineSpacing
		style.paragraphSpacing = paragraphSpacing
		return style
	}()

	func setupUI() {
		guard let contentView = window?.contentView else {
			return
		}

		let scrollView = NSTextView.scrollableTextView()
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.hasVerticalScroller = true
		scrollView.autohidesScrollers = true
		scrollView.drawsBackground = true

		let embeddedTextView = scrollView.documentView as! NSTextView
		embeddedTextView.isEditable = false
		embeddedTextView.isSelectable = true
		embeddedTextView.textContainerInset = NSSize(width: Self.textContainerInset, height: Self.textContainerInset)
		embeddedTextView.font = NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular)
		self.textView = embeddedTextView

		let separator = NSView()
		separator.translatesAutoresizingMaskIntoConstraints = false
		separator.wantsLayer = true
		separator.layer?.backgroundColor = NSColor(white: Self.separatorWhite, alpha: 1.0).cgColor

		let bottomBar = NSVisualEffectView()
		bottomBar.translatesAutoresizingMaskIntoConstraints = false
		bottomBar.blendingMode = .withinWindow
		bottomBar.material = .titlebar

		let warningLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("Errors may contain feed URLs and other information you may not want to share publicly.", comment: "Error log privacy warning"))
		warningLabel.translatesAutoresizingMaskIntoConstraints = false
		warningLabel.font = NSFont.systemFont(ofSize: Self.fontSize)
		warningLabel.textColor = .secondaryLabelColor

		let copyButton = NSButton(title: NSLocalizedString("Copy Contents", comment: "Copy Contents button"), target: self, action: #selector(copyContents(_:)))
		copyButton.translatesAutoresizingMaskIntoConstraints = false
		copyButton.controlSize = .large
		copyButton.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
		copyButton.isEnabled = false
		self.copyButton = copyButton

		bottomBar.addSubview(warningLabel)
		bottomBar.addSubview(copyButton)

		warningLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		copyButton.setContentCompressionResistancePriority(.required, for: .horizontal)
		copyButton.setContentHuggingPriority(.required, for: .horizontal)

		contentView.addSubview(scrollView)
		contentView.addSubview(separator)
		contentView.addSubview(bottomBar)

		NSLayoutConstraint.activate([
			scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
			scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			scrollView.bottomAnchor.constraint(equalTo: separator.topAnchor),

			separator.heightAnchor.constraint(equalToConstant: Self.separatorHeight),
			separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			separator.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

			warningLabel.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: Self.bottomBarPadding),
			warningLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
			warningLabel.trailingAnchor.constraint(lessThanOrEqualTo: copyButton.leadingAnchor, constant: -Self.bottomBarPadding),

			copyButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -Self.bottomBarPadding),
			copyButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

			bottomBar.heightAnchor.constraint(equalToConstant: Self.bottomBarHeight),

			bottomBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			bottomBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			bottomBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
		])
	}

	/// Load recent entries from the on-disk error log database.
	func loadEntries() {
		Task {
			let entries = await AccountManager.shared.errorLogDatabase.allEntries()
			guard !entries.isEmpty else {
				return
			}

			// Build attributed string for all entries at once,
			// replacing any entries that arrived via notifications before the window opened.
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
		guard let textStorage = textView.textStorage else {
			return
		}

		let wasScrolledToBottom = isScrolledToBottom
		let attributedEntry = attributedString(for: entry)
		textStorage.append(attributedEntry)

		if wasScrolledToBottom {
			textView.scrollToEndOfDocument(nil)
		}
		updateCopyButtonState()
	}

	func updateCopyButtonState() {
		copyButton?.isEnabled = !textView.string.isEmpty
	}

	var isScrolledToBottom: Bool {
		guard let scrollView = textView.enclosingScrollView else {
			return true
		}
		let contentView = scrollView.contentView
		let visibleMaxY = contentView.bounds.maxY
		let documentMaxY = textView.frame.maxY
		// Allow 1 point of tolerance for fractional pixel rounding.
		return visibleMaxY >= documentMaxY - 1
	}

	func attributedString(for entry: ErrorLogEntry) -> NSAttributedString {
		let result = NSMutableAttributedString()

		let timestampString = "[\(Self.dateFormatter.string(from: entry.timestamp))] "
		let timestampAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: NSColor.secondaryLabelColor,
			.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular),
			.paragraphStyle: Self.entryParagraphStyle
		]
		result.append(NSAttributedString(string: timestampString, attributes: timestampAttributes))

		let accountTypeName = AccountType(rawValue: entry.accountType)?.displayName ?? "Unknown"
		let accountNameString = "\(entry.accountName) (\(accountTypeName)): "
		let accountColor = color(for: entry.accountType)
		let accountAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: accountColor,
			.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .medium),
			.paragraphStyle: Self.entryParagraphStyle
		]
		result.append(NSAttributedString(string: accountNameString, attributes: accountAttributes))

		let messageAttributes: [NSAttributedString.Key: Any] = [
			.foregroundColor: NSColor.labelColor,
			.font: NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular),
			.paragraphStyle: Self.entryParagraphStyle
		]
		result.append(NSAttributedString(string: entry.errorMessage + "\n", attributes: messageAttributes))

		return result
	}

	func color(for accountType: Int) -> NSColor {
		guard let type = AccountType(rawValue: accountType) else {
			return .secondaryLabelColor
		}

		switch type {
		case .onMyMac:
			return .secondaryLabelColor
		case .cloudKit:
			return .systemPurple
		case .feedly:
			return .systemGreen
		case .feedbin:
			return .systemBlue
		case .newsBlur:
			return .systemOrange
		case .freshRSS:
			return .systemTeal
		case .inoreader:
			return .systemBrown
		case .bazQux:
			return .systemIndigo
		case .theOldReader:
			return .systemPink
		}
	}

	@objc func copyContents(_ sender: Any?) {
		let text = textView.string
		guard !text.isEmpty else {
			return
		}
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(text, forType: .string)
	}
}
