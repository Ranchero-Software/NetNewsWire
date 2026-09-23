//
//  AppCommands.swift
//  NetNewsWire-iOS
//
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore

@MainActor enum AppCommands {

	/// The pane a set of key commands belongs to. Global commands are attached to
	/// the split view so they work no matter which pane has focus.
	enum KeyCommandScope {
		case global
		case sidebar
		case timeline
		case detail
	}

	static func keyCommands(for scope: KeyCommandScope) -> [UIKeyCommand] {

		// Single-key shortcuts would otherwise swallow keystrokes meant for the
		// search field, so no pane supplies commands while a text field has focus.
		guard !UIResponder.isFirstResponderTextField else {
			return []
		}

		switch scope {
		case .global:
			return globalKeyCommands()
		case .sidebar:
			return sidebarKeyCommands()
		case .timeline:
			return timelineKeyCommands()
		case .detail:
			return detailKeyCommands()
		}
	}

	// The four tables below mirror the Mac app's Shared/Resources/*KeyboardShortcuts.plist,
	// which MainWindowKeyboardHandler and the sidebar, timeline and detail keyboard
	// delegates still read. iOS no longer reads them, so a shortcut that should hold on
	// both platforms has to be changed in both places.

	private static func globalKeyCommands() -> [UIKeyCommand] {
		[
			keyCommand(title: NSLocalizedString("Scroll or Go to Next Unread", comment: "Command"), action: #selector(AppCommandResponder.scrollOrGoToNextUnread(_:)), input: "\u{0020}"),
			keyCommand(title: NSLocalizedString("Scroll Up", comment: "Command"), action: #selector(AppCommandResponder.scrollUp(_:)), input: "\u{0020}", modifiers: [.shift]),
			keyCommand(title: NSLocalizedString("Go to Previous Unread", comment: "Command"), action: #selector(AppCommandResponder.goToPreviousUnread(_:)), input: "-"),
			keyCommand(action: #selector(AppCommandResponder.nextUnread(_:)), input: "+"),
			keyCommand(action: #selector(AppCommandResponder.nextUnread(_:)), input: "+", modifiers: [.shift]),
			keyCommand(title: NSLocalizedString("Next Unread", comment: "Command"), action: #selector(AppCommandResponder.nextUnread(_:)), input: "n"),
			keyCommand(title: NSLocalizedString("Mark Read", comment: "Command"), action: #selector(AppCommandResponder.toggleRead(_:)), input: "r"),
			keyCommand(title: NSLocalizedString("Mark Unread", comment: "Command"), action: #selector(AppCommandResponder.toggleRead(_:)), input: "u"),
			keyCommand(title: NSLocalizedString("Mark All as Read", comment: "Command"), action: #selector(AppCommandResponder.markAllAsRead(_:)), input: "k"),
			keyCommand(title: NSLocalizedString("Mark Unread and Go To Next Unread", comment: "Command"), action: #selector(AppCommandResponder.markUnreadAndGoToNextUnread(_:)), input: "m"),
			keyCommand(title: NSLocalizedString("Mark All as Read in Timeline and Go To Next Unread", comment: "Command"), action: #selector(AppCommandResponder.markAllAsReadAndGoToNextUnread(_:)), input: "l"),
			keyCommand(title: NSLocalizedString("Mark Older as Read", comment: "Command"), action: #selector(AppCommandResponder.markOlderArticlesAsRead(_:)), input: "o"),
			keyCommand(title: openInBrowserTitle, action: #selector(AppCommandResponder.openInBrowser(_:)), input: "b"),
			keyCommand(title: NSLocalizedString("Open In App Browser", comment: "Command"), action: #selector(AppCommandResponder.openInAppBrowser(_:)), input: "\r"),
			keyCommand(action: #selector(AppCommandResponder.openInBrowserUsingOppositeOfSettings(_:)), input: "\r", modifiers: [.shift]),
			keyCommand(title: openInBrowserInvertedTitle, action: #selector(AppCommandResponder.openInBrowserUsingOppositeOfSettings(_:)), input: "b", modifiers: [.shift]),
			keyCommand(title: NSLocalizedString("Go to Previous Feed", comment: "Command"), action: #selector(AppCommandResponder.goToPreviousSubscription(_:)), input: "a"),
			keyCommand(title: NSLocalizedString("Go to Next Feed", comment: "Command"), action: #selector(AppCommandResponder.goToNextSubscription(_:)), input: "z"),
			keyCommand(action: #selector(AppCommandResponder.toggleStarred(_:)), input: "s"),
			keyCommand(title: NSLocalizedString("Go To Settings", comment: "Command"), action: #selector(AppCommandResponder.goToSettings(_:)), input: ",", modifiers: [.command])
		]
	}

	private static func sidebarKeyCommands() -> [UIKeyCommand] {
		[
			keyCommand(title: NSLocalizedString("Select Next Up", comment: "Command"), action: #selector(AppCommandResponder.selectNextUp(_:)), input: UIKeyCommand.inputUpArrow),
			keyCommand(title: NSLocalizedString("Select Next Down", comment: "Command"), action: #selector(AppCommandResponder.selectNextDown(_:)), input: UIKeyCommand.inputDownArrow),
			keyCommand(action: #selector(AppCommandResponder.navigateToTimeline(_:)), input: "\t"),
			keyCommand(title: NSLocalizedString("Navigate to Timeline", comment: "Command"), action: #selector(AppCommandResponder.navigateToTimeline(_:)), input: UIKeyCommand.inputRightArrow),
			keyCommand(title: NSLocalizedString("Collapse Selected Row", comment: "Command"), action: #selector(AppCommandResponder.collapseSelectedRows(_:)), input: ","),
			keyCommand(title: NSLocalizedString("Collapse Selected Row", comment: "Command"), action: #selector(AppCommandResponder.collapseSelectedRows(_:)), input: UIKeyCommand.inputLeftArrow, modifiers: [.command]),
			keyCommand(title: NSLocalizedString("Expand Selected Row", comment: "Command"), action: #selector(AppCommandResponder.expandSelectedRows(_:)), input: "."),
			keyCommand(title: NSLocalizedString("Expand Selected Row", comment: "Command"), action: #selector(AppCommandResponder.expandSelectedRows(_:)), input: UIKeyCommand.inputRightArrow, modifiers: [.command]),
			keyCommand(title: NSLocalizedString("Collapse All", comment: "Command"), action: #selector(AppCommandResponder.collapseAllExceptForGroupItems(_:)), input: ";"),
			keyCommand(action: #selector(AppCommandResponder.collapseAllExceptForGroupItems(_:)), input: UIKeyCommand.inputLeftArrow, modifiers: [.command, .alternate]),
			keyCommand(title: NSLocalizedString("Expand All", comment: "Command"), action: #selector(AppCommandResponder.expandAll(_:)), input: "'"),
			keyCommand(action: #selector(AppCommandResponder.expandAll(_:)), input: UIKeyCommand.inputRightArrow, modifiers: [.command, .alternate]),
			keyCommand(title: NSLocalizedString("Delete", comment: "Command"), action: #selector(AppCommandResponder.delete(_:)), input: "\u{8}")
		]
	}

	private static func timelineKeyCommands() -> [UIKeyCommand] {
		[
			keyCommand(title: NSLocalizedString("Select Next Up", comment: "Command"), action: #selector(AppCommandResponder.selectNextUp(_:)), input: UIKeyCommand.inputUpArrow),
			keyCommand(title: NSLocalizedString("Select Next Down", comment: "Command"), action: #selector(AppCommandResponder.selectNextDown(_:)), input: UIKeyCommand.inputDownArrow),
			keyCommand(title: NSLocalizedString("Navigate to Feeds", comment: "Command"), action: #selector(AppCommandResponder.navigateToSidebar(_:)), input: UIKeyCommand.inputLeftArrow),
			keyCommand(title: NSLocalizedString("Navigate to Detail", comment: "Command"), action: #selector(AppCommandResponder.navigateToDetail(_:)), input: UIKeyCommand.inputRightArrow)
		]
	}

	private static func detailKeyCommands() -> [UIKeyCommand] {
		[
			keyCommand(title: NSLocalizedString("Navigate to Timeline", comment: "Command"), action: #selector(AppCommandResponder.navigateToTimeline(_:)), input: UIKeyCommand.inputLeftArrow)
		]
	}

	static func buildMenus(with builder: UIMenuBuilder) {
		// NetNewsWire has no rich-text editing, and Format’s Italic (⌘I)
		// conflicts with Get Feed Info. The macOS app has no Format menu either.
		builder.remove(menu: .format)

		fileMenu(builder)
		findMenu(builder)
		let hasViewMenu = builder.menu(for: .view) != nil
		viewMenu(builder, hasViewMenu: hasViewMenu)
		goMenu(builder, hasViewMenu: hasViewMenu)
		articleMenu(builder)
		windowMenu(builder)
	}
}

extension AppCommands {

	fileprivate static let newItemsMenuIdentifier = UIMenu.Identifier(rawValue: "com.ranchero.NetNewsWire.newItems")
	fileprivate static let findMenuIdentifier = UIMenu.Identifier(rawValue: "com.ranchero.NetNewsWire.find")
	fileprivate static let sortByMenuIdentifier = UIMenu.Identifier(rawValue: "com.ranchero.NetNewsWire.sortBy")
	fileprivate static let viewMenuIdentifier = UIMenu.Identifier(rawValue: "com.ranchero.NetNewsWire.view")
	fileprivate static let goMenuIdentifier = UIMenu.Identifier(rawValue: "com.ranchero.NetNewsWire.go")
	fileprivate static let articleMenuIdentifier = UIMenu.Identifier(rawValue: "com.ranchero.NetNewsWire.article")

	fileprivate static func keyCommand(title: String? = nil, action: Selector, input: String, modifiers: UIKeyModifierFlags = []) -> UIKeyCommand {
		let command: UIKeyCommand
		if let title {
			command = UIKeyCommand(title: title, action: action, input: input, modifierFlags: modifiers)
		} else {
			command = UIKeyCommand(input: input, modifierFlags: modifiers, action: action)
		}
		command.wantsPriorityOverSystemBehavior = true
		return command
	}

	/// Titles for the paired open-in-browser commands. The preference decides
	/// which one opens where, so the titles have to follow it.
	private static var openInBrowserTitle: String {
		AppDefaults.shared.useSystemBrowser ?
			NSLocalizedString("Open in Browser", comment: "Command") :
			NSLocalizedString("Open in NetNewsWire", comment: "Command")
	}

	private static var openInBrowserInvertedTitle: String {
		AppDefaults.shared.useSystemBrowser ?
			NSLocalizedString("Open in NetNewsWire", comment: "Command") :
			NSLocalizedString("Open in Browser", comment: "Command")
	}

	fileprivate static func menuCommand(title: String, action: Selector, input: String? = nil, modifiers: UIKeyModifierFlags = []) -> UIMenuElement {
		guard let input else {
			return UICommand(title: title, action: action)
		}
		let command = UIKeyCommand(title: title, action: action, input: input, modifierFlags: modifiers)

		// Several of these shortcuts (⌘F, ⌥⌘F, ⌘I) are ones UIKit also binds to
		// system text behavior, so the menu item has to win.
		command.wantsPriorityOverSystemBehavior = true
		return command
	}

	// MARK: - File

	fileprivate static func fileMenu(_ builder: UIMenuBuilder) {

		// Each group is inserted at the start of the File menu, so the groups appear
		// in the reverse of the order they're added here: New, Refresh, Import/Export.
		// That matches the Mac app's File menu.
		let importExportGroup = UIMenu(title: "", options: .displayInline, children: [
			menuCommand(title: NSLocalizedString("Import Subscriptions…", comment: "Command"), action: #selector(AppCommandResponder.importOPML(_:))),
			menuCommand(title: NSLocalizedString("Export Subscriptions…", comment: "Command"), action: #selector(AppCommandResponder.exportOPML(_:)), input: "e", modifiers: [.command, .alternate])
		])
		builder.insertChild(importExportGroup, atStartOfMenu: .file)

		let refreshGroup = UIMenu(title: "", options: .displayInline, children: [
			menuCommand(title: NSLocalizedString("Refresh", comment: "Command"), action: #selector(AppCommandResponder.refresh(_:)), input: "r", modifiers: [.command])
		])
		builder.insertChild(refreshGroup, atStartOfMenu: .file)

		let newItemsGroup = UIMenu(title: "", image: nil, identifier: newItemsMenuIdentifier, options: .displayInline, children: [
			menuCommand(title: NSLocalizedString("New Feed", comment: "Command"), action: #selector(AppCommandResponder.addNewFeed(_:)), input: "n", modifiers: [.command]),
			menuCommand(title: NSLocalizedString("New Folder", comment: "Command"), action: #selector(AppCommandResponder.addNewFolder(_:)), input: "n", modifiers: [.command, .shift])
		])
		builder.insertChild(newItemsGroup, atStartOfMenu: .file)
	}

	// MARK: - Find

	fileprivate static func findMenu(_ builder: UIMenuBuilder) {
		let findElements = [
			menuCommand(title: NSLocalizedString("Article Search", comment: "Command"), action: #selector(AppCommandResponder.articleSearch(_:)), input: "f", modifiers: [.command, .alternate]),
			menuCommand(title: NSLocalizedString("Find in Article", comment: "Command"), action: #selector(AppCommandResponder.beginFind(_:)), input: "f", modifiers: [.command])
		]

		// Replace the system Find menu: its Find (⌘F) and Find & Replace (⌥⌘F)
		// conflict with Find in Article and Article Search.
		let findMenu = UIMenu(title: NSLocalizedString("Find", comment: "Command"), identifier: findMenuIdentifier, children: findElements)
		if builder.menu(for: .find) != nil {
			builder.replace(menu: .find, with: findMenu)
		} else {
			builder.insertChild(findMenu, atEndOfMenu: .edit)
		}
	}

	// MARK: - View

	fileprivate static func viewMenu(_ builder: UIMenuBuilder, hasViewMenu: Bool) {
		let sortByMenu = UIMenu(title: NSLocalizedString("Sort Articles By", comment: "Command"), identifier: sortByMenuIdentifier, children: [
			menuCommand(title: NSLocalizedString("Newest Article on Top", comment: "Command"), action: #selector(AppCommandResponder.sortByNewestArticleOnTop(_:))),
			menuCommand(title: NSLocalizedString("Oldest Article on Top", comment: "Command"), action: #selector(AppCommandResponder.sortByOldestArticleOnTop(_:)))
		])
		let groupByFeedCommand = menuCommand(title: NSLocalizedString("Group by Feed", comment: "Command"), action: #selector(AppCommandResponder.groupByFeedToggled(_:)))
		let topGroup = UIMenu(title: "", options: .displayInline, children: [sortByMenu, groupByFeedCommand])

		let cleanUpGroup = UIMenu(title: "", options: .displayInline, children: [
			menuCommand(title: NSLocalizedString("Clean Up", comment: "Command"), action: #selector(AppCommandResponder.cleanUp(_:)), input: "'", modifiers: [.command]),
			menuCommand(title: NSLocalizedString("Hide Read Articles", comment: "Command"), action: #selector(AppCommandResponder.toggleReadArticlesFilter(_:)), input: "h", modifiers: [.command, .shift]),
			menuCommand(title: NSLocalizedString("Hide Read Feeds", comment: "Command"), action: #selector(AppCommandResponder.toggleReadFeedsFilter(_:)), input: "f", modifiers: [.command, .shift])
		])

		// No Toggle Sidebar item: the system View menu already provides
		// Show Sidebar (⌃⌘S) bound to toggleSidebar:.
		if hasViewMenu {
			builder.insertChild(cleanUpGroup, atStartOfMenu: .view)
			builder.insertChild(topGroup, atStartOfMenu: .view)
		} else {
			let viewMenu = UIMenu(title: NSLocalizedString("View", comment: "Command"), identifier: viewMenuIdentifier, children: [topGroup, cleanUpGroup])
			builder.insertSibling(viewMenu, afterMenu: .edit)
		}
	}

	// MARK: - Go

	fileprivate static func goMenu(_ builder: UIMenuBuilder, hasViewMenu: Bool) {
		let nextUnreadCommand = menuCommand(title: NSLocalizedString("Next Unread", comment: "Command"), action: #selector(AppCommandResponder.nextUnread(_:)), input: "/", modifiers: [.command])
		let smartFeedsGroup = UIMenu(title: "", options: .displayInline, children: [
			menuCommand(title: NSLocalizedString("Today", comment: "Command"), action: #selector(AppCommandResponder.goToToday(_:)), input: "1", modifiers: [.command]),
			menuCommand(title: NSLocalizedString("All Unread", comment: "Command"), action: #selector(AppCommandResponder.goToAllUnread(_:)), input: "2", modifiers: [.command]),
			menuCommand(title: NSLocalizedString("Starred", comment: "Command"), action: #selector(AppCommandResponder.goToStarred(_:)), input: "3", modifiers: [.command])
		])

		let goMenu = UIMenu(title: NSLocalizedString("Go", comment: "Command"), identifier: goMenuIdentifier, children: [nextUnreadCommand, smartFeedsGroup])

		if hasViewMenu {
			builder.insertSibling(goMenu, afterMenu: .view)
		} else {
			// Anchor to the custom View menu inserted above. Anchoring to .edit
			// would place Go ahead of View, since each insert lands immediately
			// after its anchor.
			builder.insertSibling(goMenu, afterMenu: viewMenuIdentifier)
		}
	}

	// MARK: - Article

	fileprivate static func articleMenu(_ builder: UIMenuBuilder) {
		let markGroup = UIMenu(title: "", options: .displayInline, children: [
			menuCommand(title: NSLocalizedString("Mark as Read", comment: "Command"), action: #selector(AppCommandResponder.toggleRead(_:)), input: "u", modifiers: [.command, .shift]),
			menuCommand(title: NSLocalizedString("Mark All as Read", comment: "Command"), action: #selector(AppCommandResponder.markAllAsRead(_:)), input: "k", modifiers: [.command]),
			menuCommand(title: NSLocalizedString("Mark Above as Read", comment: "Command"), action: #selector(AppCommandResponder.markAboveAsRead(_:)), input: "k", modifiers: [.command, .control]),
			menuCommand(title: NSLocalizedString("Mark Below as Read", comment: "Command"), action: #selector(AppCommandResponder.markBelowAsRead(_:)), input: "k", modifiers: [.command, .shift])
		])

		let starredGroup = UIMenu(title: "", options: .displayInline, children: [
			menuCommand(title: NSLocalizedString("Mark as Starred", comment: "Command"), action: #selector(AppCommandResponder.toggleStarred(_:)), input: "l", modifiers: [.command, .shift])
		])

		let readerGroup = UIMenu(title: "", options: .displayInline, children: [
			menuCommand(title: NSLocalizedString("Show Reader View", comment: "Command"), action: #selector(AppCommandResponder.toggleReaderView(_:)), input: "r", modifiers: [.command, .shift]),
			menuCommand(title: openInBrowserTitle, action: #selector(AppCommandResponder.openArticleInBrowser(_:)), input: UIKeyCommand.inputRightArrow, modifiers: [.command]),
			menuCommand(title: openInBrowserInvertedTitle, action: #selector(AppCommandResponder.openInBrowserUsingOppositeOfSettings(_:)), input: UIKeyCommand.inputRightArrow, modifiers: [.command, .shift]),
			menuCommand(title: NSLocalizedString("Get Feed Info", comment: "Command"), action: #selector(AppCommandResponder.showFeedInspector(_:)), input: "i", modifiers: [.command])
		])

		let articleMenu = UIMenu(title: NSLocalizedString("Article", comment: "Command"), identifier: articleMenuIdentifier, children: [markGroup, starredGroup, readerGroup])
		builder.insertSibling(articleMenu, afterMenu: goMenuIdentifier)
	}

	// MARK: - Window

	fileprivate static func windowMenu(_ builder: UIMenuBuilder) {
		guard builder.menu(for: .window) != nil else {
			return
		}
		let currentActivityGroup = UIMenu(title: "", options: .displayInline, children: [
			menuCommand(title: NSLocalizedString("Current Activity", comment: "Command"), action: #selector(AppCommandResponder.showCurrentActivity(_:)), input: "7", modifiers: [.command])
		])
		builder.insertChild(currentActivityGroup, atStartOfMenu: .window)
	}
}

/// The responder-chain actions bound to the key commands and menu items above.
///
/// No single object conforms to this protocol; its methods are implemented
/// piecemeal across the responder chain (the split view, feeds, timeline, and
/// article view controllers). Declaring them here lets the tables above use
/// `#selector`, so a misspelled or renamed action is a compile error rather than
/// a silently dead shortcut.
@objc private protocol AppCommandResponder {

	// Global
	func scrollOrGoToNextUnread(_ sender: Any?)
	func scrollUp(_ sender: Any?)
	func goToPreviousUnread(_ sender: Any?)
	func nextUnread(_ sender: Any?)
	func toggleRead(_ sender: Any?)
	func markAllAsRead(_ sender: Any?)
	func markUnreadAndGoToNextUnread(_ sender: Any?)
	func markAllAsReadAndGoToNextUnread(_ sender: Any?)
	func markOlderArticlesAsRead(_ sender: Any?)
	func markAboveAsRead(_ sender: Any?)
	func markBelowAsRead(_ sender: Any?)
	func openInBrowser(_ sender: Any?)
	func openInAppBrowser(_ sender: Any?)
	func openInBrowserUsingOppositeOfSettings(_ sender: Any?)
	func goToPreviousSubscription(_ sender: Any?)
	func goToNextSubscription(_ sender: Any?)
	func toggleStarred(_ sender: Any?)
	func goToSettings(_ sender: Any?)

	// Sidebar / Timeline / Detail
	func selectNextUp(_ sender: Any?)
	func selectNextDown(_ sender: Any?)
	func navigateToTimeline(_ sender: Any?)
	func navigateToSidebar(_ sender: Any?)
	func navigateToDetail(_ sender: Any?)
	func collapseSelectedRows(_ sender: Any?)
	func expandSelectedRows(_ sender: Any?)
	func collapseAllExceptForGroupItems(_ sender: Any?)
	func expandAll(_ sender: Any?)
	func delete(_ sender: Any?)

	// File
	func importOPML(_ sender: Any?)
	func exportOPML(_ sender: Any?)
	func refresh(_ sender: Any?)
	func addNewFeed(_ sender: Any?)
	func addNewFolder(_ sender: Any?)

	// Find
	func articleSearch(_ sender: Any?)
	func beginFind(_ sender: Any?)

	// View
	func sortByNewestArticleOnTop(_ sender: Any?)
	func sortByOldestArticleOnTop(_ sender: Any?)
	func groupByFeedToggled(_ sender: Any?)
	func cleanUp(_ sender: Any?)
	func toggleReadArticlesFilter(_ sender: Any?)
	func toggleReadFeedsFilter(_ sender: Any?)

	// Go
	func goToToday(_ sender: Any?)
	func goToAllUnread(_ sender: Any?)
	func goToStarred(_ sender: Any?)

	// Article
	func openArticleInBrowser(_ sender: Any?)
	func toggleReaderView(_ sender: Any?)
	func showFeedInspector(_ sender: Any?)

	// Window
	func showCurrentActivity(_ sender: Any?)
}
