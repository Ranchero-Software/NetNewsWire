//
//  AccountStatsViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/7/26.
//

import AppKit

final class AccountStatsViewController: NSViewController {

	private let model = AccountStatsViewModel()
	private let scrollView = NSScrollView()
	private let tableView = NSTableView()
	private let footerView = AccountStatsFooterView()

	override func loadView() {
		let containerView = NSView()
		containerView.translatesAutoresizingMaskIntoConstraints = false

		configureScrollView()
		configureTableView()

		containerView.addSubview(scrollView)
		containerView.addSubview(footerView)

		NSLayoutConstraint.activate([
			scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
			scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
			scrollView.bottomAnchor.constraint(equalTo: footerView.topAnchor),

			footerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
			footerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
			footerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
		])

		self.view = containerView
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		NotificationCenter.default.addObserver(self, selector: #selector(handleAccountStatsDidChange(_:)), name: .AccountStatsDidChange, object: model)
	}

	override func viewDidAppear() {
		super.viewDidAppear()
		model.refresh()
	}

	@objc func handleAccountStatsDidChange(_ notification: Notification) {
		updateUI()
	}

	@objc func refresh(_ sender: Any?) {
		model.refresh()
	}

	@objc func vacuum(_ sender: Any?) {
		model.vacuum()
	}
}

// MARK: - NSTableViewDataSource

extension AccountStatsViewController: NSTableViewDataSource {

	func numberOfRows(in tableView: NSTableView) -> Int {
		model.accountStats.count
	}
}

// MARK: - NSTableViewDelegate

extension AccountStatsViewController: NSTableViewDelegate {

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn else {
			return nil
		}
		guard row < model.accountStats.count else {
			return nil
		}
		let stats = model.accountStats[row]
		let identifier = tableColumn.identifier
		let columnKind = columnKind(for: identifier)

		let cell: NSTableCellView
		if let recycled = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
			cell = recycled
		} else {
			cell = Self.makeCell(identifier: identifier, alignment: columnKind.alignment)
		}

		let textField = cell.textField!
		textField.stringValue = text(for: columnKind, stats: stats)
		textField.textColor = stats.isActive ? .labelColor : .secondaryLabelColor
		textField.font = columnKind.usesMonospacedDigits
			? NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
			: NSFont.systemFont(ofSize: NSFont.systemFontSize)
		return cell
	}
}

// MARK: - Private

private extension AccountStatsViewController {

	enum ColumnKind: String, CaseIterable {

		case account, feeds, folders, articles, unread, starred, dbSize

		var identifier: NSUserInterfaceItemIdentifier {
			NSUserInterfaceItemIdentifier(rawValue)
		}

		var title: String {
			switch self {
			case .account:
				return NSLocalizedString("Account", comment: "Account column header")
			case .feeds:
				return NSLocalizedString("Feeds", comment: "Feeds column header")
			case .folders:
				return NSLocalizedString("Folders", comment: "Folders column header")
			case .articles:
				return NSLocalizedString("Articles", comment: "Articles column header")
			case .unread:
				return NSLocalizedString("Unread", comment: "Unread column header")
			case .starred:
				return NSLocalizedString("Starred", comment: "Starred column header")
			case .dbSize:
				return NSLocalizedString("Database", comment: "Database size column header")
			}
		}

		var width: CGFloat {
			switch self {
			case .account:
				return 130
			case .feeds, .folders, .articles, .unread, .starred, .dbSize:
				return 80
			}
		}

		var alignment: NSTextAlignment {
			switch self {
			case .account:
				return .left
			default:
				return .right
			}
		}

		var usesMonospacedDigits: Bool {
			alignment == .right
		}

		var flexes: Bool {
			self == .account
		}
	}

	func configureScrollView() {
		scrollView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.hasVerticalScroller = true
		scrollView.hasHorizontalScroller = false
		scrollView.drawsBackground = true
		scrollView.documentView = tableView
	}

	func configureTableView() {
		tableView.translatesAutoresizingMaskIntoConstraints = false
		tableView.usesAlternatingRowBackgroundColors = true
		tableView.rowSizeStyle = .default
		tableView.allowsColumnReordering = false
		tableView.allowsColumnSelection = false
		tableView.allowsEmptySelection = true
		tableView.allowsMultipleSelection = false
		tableView.style = .inset
		tableView.delegate = self
		tableView.dataSource = self

		for kind in ColumnKind.allCases {
			let column = NSTableColumn(identifier: kind.identifier)
			column.title = kind.title
			column.width = kind.width
			column.minWidth = kind.width
			column.headerCell.alignment = kind.alignment
			column.resizingMask = kind.flexes ? [.userResizingMask, .autoresizingMask] : [.userResizingMask]
			tableView.addTableColumn(column)
		}
	}

	func updateUI() {
		tableView.reloadData()
		footerView.updateTotals(model)
		footerView.updateVacuumState(model.isVacuuming)
	}

	func columnKind(for identifier: NSUserInterfaceItemIdentifier) -> ColumnKind {
		ColumnKind(rawValue: identifier.rawValue) ?? .account
	}

	func text(for kind: ColumnKind, stats: AccountStatsData) -> String {
		switch kind {
		case .account:
			if stats.name == stats.typeName {
				return stats.name
			}
			return "\(stats.name) (\(stats.typeName))"
		case .feeds:
			return AccountStatsLayout.formattedNumber(stats.feedCount)
		case .folders:
			return AccountStatsLayout.formattedNumber(stats.folderCount)
		case .articles:
			return AccountStatsLayout.formattedNumber(stats.totalArticleCount)
		case .unread:
			return AccountStatsLayout.formattedNumber(stats.unreadCount)
		case .starred:
			return AccountStatsLayout.formattedNumber(stats.starredCount)
		case .dbSize:
			return AccountStatsLayout.formattedSize(stats.databaseSizeBytes)
		}
	}

	static func makeCell(identifier: NSUserInterfaceItemIdentifier, alignment: NSTextAlignment) -> NSTableCellView {
		let cell = NSTableCellView()
		cell.identifier = identifier

		let textField = NSTextField(labelWithString: "")
		textField.translatesAutoresizingMaskIntoConstraints = false
		textField.alignment = alignment
		textField.lineBreakMode = .byTruncatingTail
		cell.addSubview(textField)
		cell.textField = textField

		NSLayoutConstraint.activate([
			textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
			textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
			textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
		])

		return cell
	}
}
