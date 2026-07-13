//
//  DinosaursWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/31/26.
//

import AppKit
import Account
import RSCore
import RSWeb

final class DinosaursWindowController: NSWindowController {

	private static let windowIsOpenKey = "DinosaurWindowIsOpen"
	private static let monthThresholdKey = "DinosaurMonthThreshold"

	static private(set) var shouldOpenAtStartup: Bool {
		get {
			UserDefaults.standard.bool(forKey: windowIsOpenKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Self.windowIsOpenKey)
		}
	}

	private static var savedMonthThreshold: Int {
		get {
			let value = UserDefaults.standard.integer(forKey: monthThresholdKey)
			return value == 0 ? 6 : value
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Self.monthThresholdKey)
		}
	}

	@IBOutlet private var tableView: UtilityTableView?
	@IBOutlet private var monthThresholdField: NSTextField?
	@IBOutlet private var monthThresholdStepper: NSStepper?
	@IBOutlet private var selectInSidebarButton: NSButton?
	@IBOutlet private var deleteButton: NSButton?
	@IBOutlet private var openHomePageButton: NSButton?
	@IBOutlet private var copyFeedURLButton: NSButton?

	private let model = DinosaursViewModel()
	private let dinosaursUndoManager = UndoManager()
	private var hasBeenShown = false

	convenience init() {
		self.init(windowNibName: "DinosaursWindow")
	}

	override func windowDidLoad() {
		super.windowDidLoad()
		window?.delegate = self

		model.monthThreshold = Self.savedMonthThreshold
		setThresholdControls(model.monthThreshold)
		monthThresholdField?.delegate = self

		tableView?.sortDescriptors = [NSSortDescriptor(key: DinosaurSortKey.lastArticleDate.rawValue, ascending: false)]
		model.sortBy(.lastArticleDate, ascending: false)

		updateActionBarEnabledState()

		NotificationCenter.default.addObserver(self, selector: #selector(handleFaviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleFeedIconDidBecomeAvailable(_:)), name: .feedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
	}

	override func showWindow(_ sender: Any?) {
		if !hasBeenShown {
			hasBeenShown = true
			window?.center()
		}
		super.showWindow(sender)
		refreshModel()
	}

	func saveState() {
		Self.shouldOpenAtStartup = window?.isVisible ?? false
	}

	@IBAction func applyThreshold(_ sender: Any?) {
		guard let control = sender as? NSControl else {
			return
		}
		if control === monthThresholdField && control.stringValue.isEmpty {
			// Empty field shows nothing; handled live in controlTextDidChange. Don't snap to a value on commit.
			return
		}
		let value = max(1, min(350, control.integerValue))
		setThresholdControls(value)
		guard value != model.monthThreshold else {
			return
		}
		model.monthThreshold = value
		Self.savedMonthThreshold = value
		refreshModel()
	}

	@IBAction func selectInSidebar(_ sender: Any?) {
		guard let tableView, tableView.selectedRowIndexes.count == 1, let row = selectedRows.first else {
			return
		}
		NSApp.sendAction(#selector(AppDelegate.selectFeedInSidebar(_:)), to: nil, from: row.feed)
	}

	@IBAction func deleteSelectedFeeds(_ sender: Any?) {
		let rows = selectedRows
		guard !rows.isEmpty, let tableView, let window else {
			return
		}

		let alert = NSAlert()
		alert.alertStyle = .warning
		if rows.count == 1, let only = rows.first {
			alert.messageText = NSLocalizedString("Delete Feed", comment: "Delete Feed")
			let format = NSLocalizedString("Are you sure you want to delete the feed “%@”?", comment: "Delete feed alert message")
			alert.informativeText = String(format: format, only.feedName)
		} else {
			alert.messageText = NSLocalizedString("Delete Feeds", comment: "Delete Feeds")
			let format = NSLocalizedString("Are you sure you want to delete %d feeds?", comment: "Delete feeds alert message")
			alert.informativeText = String(format: format, rows.count)
		}
		alert.addButton(withTitle: NSLocalizedString("Delete", comment: "Delete button"))
		alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button"))

		let selectedIndexes = tableView.selectedRowIndexes
		alert.beginSheetModal(for: window) { [weak self] response in
			guard response == .alertFirstButtonReturn, let self else {
				return
			}
			let deletions = self.model.deleteFeeds(at: selectedIndexes)
			self.registerUndoableDelete(deletions)
			self.refreshModel()
		}
	}

	@IBAction func goToHomePage(_ sender: Any?) {
		for row in selectedRows {
			if let homePageURL = row.feed.homePageURL, !homePageURL.isEmpty, let url = URL(string: homePageURL) {
				MacWebBrowser.openURL(url)
			} else if let url = Self.rootURL(for: row.feedURL) {
				MacWebBrowser.openURL(url)
			}
		}
	}

	@IBAction func copyFeedURL(_ sender: Any?) {
		let urlStrings = selectedRows.map(\.feedURL)
		guard !urlStrings.isEmpty else {
			return
		}
		URLPasteboardWriter.write(urlStrings: urlStrings, to: .general)
	}

	@IBAction func showDinosaursHelp(_ sender: Any?) {
		if let url = URL(string: "https://netnewswire.com/help/dinosaurs.html") {
			MacWebBrowser.openURL(url)
		}
	}

	@objc func handleFaviconDidBecomeAvailable(_ notification: Notification) {
		reloadFeedColumn()
	}

	@objc func handleFeedIconDidBecomeAvailable(_ notification: Notification) {
		guard let feed = notification.userInfo?[UserInfoKey.feed] as? Feed else {
			return
		}
		reloadFeedColumn(for: feed)
	}

	@objc func handleChildrenDidChange(_ notification: Notification) {
		refreshModel()
	}
}

// MARK: - NSWindowDelegate

extension DinosaursWindowController: NSWindowDelegate {

	func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
		dinosaursUndoManager
	}
}

// MARK: - NSTextFieldDelegate

extension DinosaursWindowController: NSTextFieldDelegate {

	func controlTextDidChange(_ notification: Notification) {
		guard let field = notification.object as? NSTextField, field === monthThresholdField else {
			return
		}
		let digitsOnly = field.stringValue.filter { $0.isASCII && $0.isNumber }
		if digitsOnly != field.stringValue {
			field.stringValue = digitsOnly
		}
		applyTypedThreshold(digitsOnly)
	}
}

// MARK: - NSTableViewDataSource

extension DinosaursWindowController: NSTableViewDataSource {

	func numberOfRows(in tableView: NSTableView) -> Int {
		model.rows.count
	}

	func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		guard let descriptor = tableView.sortDescriptors.first, let rawKey = descriptor.key, let key = DinosaurSortKey(rawValue: rawKey) else {
			return
		}
		model.sortBy(key, ascending: descriptor.ascending)
		tableView.reloadData()
	}
}

// MARK: - NSTableViewDelegate

extension DinosaursWindowController: NSTableViewDelegate {

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn, row < model.rows.count else {
			return nil
		}
		let identifier = tableColumn.identifier
		let kind = columnKind(for: identifier)
		guard let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView else {
			return nil
		}
		let dinosaur = model.rows[row]
		cell.textField?.stringValue = text(for: kind, row: dinosaur)
		cell.textField?.font = kind.usesMonospacedDigits
			? NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
			: NSFont.systemFont(ofSize: NSFont.systemFontSize)
		if kind == .name {
			cell.imageView?.image = IconImageCache.shared.imageForFeed(dinosaur.feed)?.image
		}
		return cell
	}

	func tableViewSelectionDidChange(_ notification: Notification) {
		updateActionBarEnabledState()
	}
}

// MARK: - Private

private extension DinosaursWindowController {

	static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter
	}()

	enum ColumnKind: String {

		case name = "feed"
		case url
		case account
		case lastArticle
		case lastResponse

		var usesMonospacedDigits: Bool {
			switch self {
			case .lastArticle, .lastResponse:
				return true
			default:
				return false
			}
		}
	}

	var selectedRows: [DinosaurRow] {
		guard let tableView else {
			return []
		}
		return tableView.selectedRowIndexes.compactMap { index in
			model.rows.indices.contains(index) ? model.rows[index] : nil
		}
	}

	func refreshModel() {
		let previousSelection = Set(selectedRows.map(\.id))
		Task {
			await model.refresh()
			updateUI()
			restoreSelection(previousSelection)
		}
	}

	func restoreSelection(_ ids: Set<String>) {
		guard let tableView, !ids.isEmpty else {
			return
		}
		let newIndexes = IndexSet(model.rows.enumerated().compactMap { ids.contains($1.id) ? $0 : nil })
		tableView.selectRowIndexes(newIndexes, byExtendingSelection: false)
	}

	func updateUI() {
		if let accountColumn = tableView?.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(ColumnKind.account.rawValue)) {
			accountColumn.isHidden = !model.showAccountColumn
		}
		tableView?.reloadData()
		updateActionBarEnabledState()
	}

	func registerUndoableDelete(_ deletions: [DinosaurDeletion]) {
		guard let undoManager = window?.undoManager else {
			return
		}
		undoManager.registerUndo(withTarget: self) { controller in
			controller.model.performRestorations(deletions)
			controller.registerUndoableRestore(deletions)
			controller.refreshModel()
		}
		let actionName = deletions.count == 1
			? NSLocalizedString("Delete Feed", comment: "Delete Feed")
			: NSLocalizedString("Delete Feeds", comment: "Delete Feeds")
		undoManager.setActionName(actionName)
	}

	func registerUndoableRestore(_ deletions: [DinosaurDeletion]) {
		guard let undoManager = window?.undoManager else {
			return
		}
		undoManager.registerUndo(withTarget: self) { controller in
			controller.model.performDeletions(deletions)
			controller.registerUndoableDelete(deletions)
			controller.refreshModel()
		}
	}

	func reloadFeedColumn(for feed: Feed? = nil) {
		guard let tableView, let columnIndex = feedColumnIndex else {
			return
		}
		let rowIndexes: IndexSet
		if let feed {
			rowIndexes = IndexSet(model.rows.enumerated().compactMap { $1.feed == feed ? $0 : nil })
		} else {
			rowIndexes = IndexSet(integersIn: 0..<model.rows.count)
		}
		guard !rowIndexes.isEmpty else {
			return
		}
		tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: IndexSet(integer: columnIndex))
	}

	static func rootURL(for feedURL: String) -> URL? {
		guard var components = URLComponents(string: feedURL), components.host != nil else {
			return nil
		}
		components.path = "/"
		components.query = nil
		components.fragment = nil
		return components.url
	}

	var feedColumnIndex: Int? {
		let index = tableView?.column(withIdentifier: NSUserInterfaceItemIdentifier(ColumnKind.name.rawValue)) ?? -1
		return index >= 0 ? index : nil
	}

	func setThresholdControls(_ value: Int) {
		monthThresholdField?.integerValue = value
		monthThresholdStepper?.integerValue = value
	}

	func applyTypedThreshold(_ text: String) {
		guard let value = Int(text), value >= 1 else {
			// Empty field, or no usable number: show nothing.
			model.clear()
			updateUI()
			return
		}
		let clamped = min(350, value)
		monthThresholdStepper?.integerValue = clamped
		model.monthThreshold = clamped
		Self.savedMonthThreshold = clamped
		refreshModel()
	}

	func updateActionBarEnabledState() {
		let count = tableView?.selectedRowIndexes.count ?? 0
		selectInSidebarButton?.isEnabled = count == 1
		deleteButton?.isEnabled = count > 0
		openHomePageButton?.isEnabled = count > 0
		copyFeedURLButton?.isEnabled = count > 0
	}

	func columnKind(for identifier: NSUserInterfaceItemIdentifier) -> ColumnKind {
		ColumnKind(rawValue: identifier.rawValue) ?? .name
	}

	func text(for kind: ColumnKind, row: DinosaurRow) -> String {
		switch kind {
		case .name:
			return row.feedName
		case .url:
			return row.feedURL
		case .account:
			return row.accountName
		case .lastArticle:
			return row.lastArticleDate.map { Self.dateFormatter.string(from: $0) } ?? "—"
		case .lastResponse:
			return row.lastResponseCode.map(String.init) ?? "—"
		}
	}
}
