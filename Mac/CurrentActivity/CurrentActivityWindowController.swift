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

	private let model = CurrentActivityViewModel()
	private var hasBeenShown = false

	private static let aboveCenterOffset: CGFloat = 40

	convenience init() {
		self.init(windowNibName: "CurrentActivityWindow")
	}

	override func windowDidLoad() {
		super.windowDidLoad()
		window?.delegate = self
		model.displayedActivitiesDidChange = { [weak self] in
			self?.tableView?.reloadData()
		}
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
		model.start()
	}

	func saveState() {
		Self.shouldOpenAtStartup = window?.isVisible ?? false
	}

	// MARK: - NSWindowDelegate

	func windowWillClose(_ notification: Notification) {
		model.stop()
	}

	// MARK: - NSTableViewDataSource

	func numberOfRows(in tableView: NSTableView) -> Int {
		model.displayedActivities.count
	}

	// MARK: - NSTableViewDelegate

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn, row < model.displayedActivities.count else {
			return nil
		}
		guard let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView else {
			return nil
		}
		let activity = model.displayedActivities[row]
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

	// MARK: - Actions

	@IBAction func showHelp(_ sender: Any?) {
		if let url = URL(string: "https://netnewswire.com/help/current-activity.html") {
			MacWebBrowser.openURL(url)
		}
	}
}

// MARK: - Private

private extension CurrentActivityWindowController {

	func configureStateImage(_ cell: NSTableCellView, for activity: Activity) {
		let color: NSColor
		switch activity.state {
		case .pending:
			color = .tertiaryLabelColor
		case .running:
			color = .systemBlue
		case .completed:
			color = .systemGreen
		case .failed:
			color = .systemRed
		}
		let symbol = CurrentActivityViewModel.symbolName(for: activity.state)
		let label = CurrentActivityViewModel.accessibilityLabel(for: activity.state)
		cell.imageView?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
		cell.imageView?.contentTintColor = color
	}

	func attributedDisplayName(for activity: Activity) -> NSAttributedString {
		let text = CurrentActivityViewModel.displayText(for: activity)
		return attributedActivity(primary: text.title, secondary: text.detail)
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
