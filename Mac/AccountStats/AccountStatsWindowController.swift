//
//  AccountStatsWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/7/26.
//

import AppKit
import Account
import RSCore
import RSWeb

final class AccountStatsWindowController: NSWindowController {

	private static let windowIsOpenKey = "AccountStatsWindowIsOpen"

	static private(set) var shouldOpenAtStartup: Bool {
		get {
			UserDefaults.standard.bool(forKey: windowIsOpenKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Self.windowIsOpenKey)
		}
	}

	@IBOutlet private var tableView: UtilityTableView?
	@IBOutlet private var vacuumButton: NSButton?
	@IBOutlet private var vacuumSpinner: NSProgressIndicator?

	private let model = AccountStatsViewModel()
	private var hasBeenShown = false
	private var hasFittedColumns = false
	private var isVacuuming = false {
		didSet {
			updateVacuumUI()
		}
	}

	convenience init() {
		self.init(windowNibName: "AccountStatsWindow")
	}

	override func windowDidLoad() {
		super.windowDidLoad()
		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountsDidChange(_:)), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountsDidChange(_:)), name: .UserDidDeleteAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountsDidChange(_:)), name: .AccountStateDidChange, object: nil)
	}

	override func showWindow(_ sender: Any?) {
		if !hasBeenShown {
			hasBeenShown = true
			window?.center()
		}
		if !hasFittedColumns {
			fitColumnsToLocalizedHeaders()
			hasFittedColumns = true
		}
		super.showWindow(sender)
		refreshModel()
	}

	func saveState() {
		Self.shouldOpenAtStartup = window?.isVisible ?? false
	}

	@objc func handleAccountsDidChange(_ notification: Notification) {
		refreshModel()
	}

	@objc func refresh(_ sender: Any?) {
		refreshModel()
	}

	@objc func vacuum(_ sender: Any?) {
		guard !isVacuuming else {
			return
		}
		isVacuuming = true
		Task {
			await appDelegate.vacuumAllDatabases()
			isVacuuming = false
			refreshModel()
		}
	}

	@objc func showHelp(_ sender: Any?) {
		if let url = URL(string: "https://netnewswire.com/help/account-stats.html") {
			MacWebBrowser.openURL(url)
		}
	}
}

// MARK: - NSTableViewDataSource

extension AccountStatsWindowController: NSTableViewDataSource {

	func numberOfRows(in tableView: NSTableView) -> Int {
		model.sortedAccountStats.count + (showsTotalsRow ? 1 : 0)
	}

	func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		model.sortDescriptor = tableView.sortDescriptors.first
		model.applySort()
		tableView.reloadData()
	}
}

// MARK: - NSTableViewDelegate

extension AccountStatsWindowController: NSTableViewDelegate {

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn else {
			return nil
		}
		let identifier = tableColumn.identifier
		let columnKind = columnKind(for: identifier)

		guard let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView else {
			return nil
		}
		guard let textField = cell.textField else {
			return cell
		}

		let pointSize = textField.font?.pointSize ?? NSFont.systemFontSize

		if row == totalsRowIndex {
			let font = columnKind.usesMonospacedDigits
				? NSFont.monospacedDigitSystemFont(ofSize: pointSize, weight: .bold)
				: NSFont.boldSystemFont(ofSize: pointSize)
			let paragraph = NSMutableParagraphStyle()
			paragraph.alignment = columnKind.alignment
			textField.alignment = columnKind.alignment
			textField.attributedStringValue = NSAttributedString(
				string: totalsText(for: columnKind),
				attributes: [
					.font: font,
					.foregroundColor: NSColor.labelColor,
					.paragraphStyle: paragraph
				]
			)
			return cell
		}

		guard row < model.sortedAccountStats.count else {
			return nil
		}
		let accountData = model.sortedAccountStats[row]
		textField.stringValue = text(for: columnKind, stats: accountData)
		textField.textColor = accountData.isActive ? .labelColor : .secondaryLabelColor
		textField.alignment = columnKind.alignment
		textField.font = columnKind.usesMonospacedDigits
			? NSFont.monospacedDigitSystemFont(ofSize: pointSize, weight: .regular)
			: NSFont.systemFont(ofSize: pointSize)
		return cell
	}
}

// MARK: - Private

private extension AccountStatsWindowController {

	enum ColumnKind: String {

		case account, dbSize, feeds, folders, articles, statuses, unread, starred

		var alignment: NSTextAlignment {
			switch self {
			case .account:
				return .left
			default:
				return .right
			}
		}

		var usesMonospacedDigits: Bool {
			self != .account
		}
	}

	func refreshModel() {
		Task {
			await model.refresh()
			tableView?.reloadData()
		}
	}

	func updateVacuumUI() {
		vacuumButton?.isEnabled = !isVacuuming
		vacuumSpinner?.isHidden = !isVacuuming
		if isVacuuming {
			vacuumSpinner?.startAnimation(nil)
		} else {
			vacuumSpinner?.stopAnimation(nil)
		}
	}

	func fitColumnsToLocalizedHeaders() {
		guard let tableView else {
			return
		}
		// Cell-side padding (~6pt each side) + sort-indicator triangle (~12pt) + breathing.
		let headerPadding: CGFloat = 28
		// Extra width above the minimum so the user has room to drag a column narrower.
		let shrinkSlack: CGFloat = 28
		let headerFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
		var totalColumnWidth: CGFloat = 0
		for column in tableView.tableColumns {
			let title = column.headerCell.stringValue
			let titleWidth = (title as NSString).size(withAttributes: [.font: headerFont]).width
			let required = ceil(titleWidth) + headerPadding
			if required > column.minWidth {
				column.minWidth = required
			}
			if required > column.width {
				column.width = required + shrinkSlack
			}
			totalColumnWidth += column.width
		}

		// The XIB's contentMinSize was sized for English. Widen it if the localized
		// columns plus chrome can't fit, otherwise the table view squeezes columns
		// below their minWidth and they clip.
		guard let window else {
			return
		}
		let intercellSpacing = tableView.intercellSpacing.width * CGFloat(tableView.tableColumns.count - 1)
		let chrome: CGFloat = 24  // vertical scroller + a little slack
		let requiredContentWidth = ceil(totalColumnWidth + intercellSpacing + chrome)
		if requiredContentWidth > window.contentMinSize.width {
			window.contentMinSize = NSSize(width: requiredContentWidth, height: window.contentMinSize.height)
		}
		if requiredContentWidth > window.frame.size.width {
			var frame = window.frame
			frame.size.width = requiredContentWidth
			window.setFrame(frame, display: true)
		}
	}

	var showsTotalsRow: Bool {
		model.sortedAccountStats.count > 1
	}

	var totalsRowIndex: Int? {
		showsTotalsRow ? model.sortedAccountStats.count : nil
	}

	func columnKind(for identifier: NSUserInterfaceItemIdentifier) -> ColumnKind {
		ColumnKind(rawValue: identifier.rawValue) ?? .account
	}

	func totalsText(for kind: ColumnKind) -> String {
		switch kind {
		case .account:
			return NSLocalizedString("Totals", comment: "Totals section")
		case .feeds:
			return Self.formattedNumber(model.totals.feedCount)
		case .folders:
			return Self.formattedNumber(model.totals.folderCount)
		case .articles:
			return Self.formattedNumber(model.totals.articleCount)
		case .statuses:
			return Self.formattedNumber(model.totals.statusesCount)
		case .unread:
			return Self.formattedNumber(model.totals.unreadCount)
		case .starred:
			return Self.formattedNumber(model.totals.starredCount)
		case .dbSize:
			return Self.formattedSize(model.totals.databaseSizeBytes)
		}
	}

	func text(for kind: ColumnKind, stats: AccountStatsRowData) -> String {
		switch kind {
		case .account:
			if stats.name == stats.typeName {
				return stats.name
			}
			return "\(stats.name) (\(stats.typeName))"
		case .feeds:
			return Self.formattedNumber(stats.feedCount)
		case .folders:
			return Self.formattedNumber(stats.folderCount)
		case .articles:
			return Self.formattedNumber(stats.articleCount)
		case .statuses:
			return Self.formattedNumber(stats.statusesCount)
		case .unread:
			return Self.formattedNumber(stats.unreadCount)
		case .starred:
			return Self.formattedNumber(stats.starredCount)
		case .dbSize:
			return Self.formattedSize(stats.databaseSizeBytes)
		}
	}

	static func formattedNumber(_ value: Int) -> String {
		value.formatted(.number)
	}

	static func formattedSize(_ bytes: Int) -> String {
		Int64(bytes).formatted(.byteCount(style: .file))
	}
}
