//
//  KeyboardManager.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/4/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

enum KeyboardType: String {
	case global = "GlobalKeyboardShortcuts"
	case sidebar = "SidebarKeyboardShortcuts"
	case timeline = "TimelineKeyboardShortcuts"
	case detail = "DetailKeyboardShortcuts"
}

@MainActor final class KeyboardManager {
	
	private(set) var _keyCommands: [UIKeyCommand]
	var keyCommands: [UIKeyCommand] {
		guard !UIResponder.isFirstResponderTextField else { return [UIKeyCommand]() }
		return _keyCommands
	}
		
	init(type: KeyboardType) {
		_keyCommands = KeyboardManager.globalAuxilaryKeyCommands()
		
		switch type {
		case .sidebar:
			_keyCommands.append(contentsOf: KeyboardManager.hardcodeFeedKeyCommands())
		case .timeline, .detail:
			_keyCommands.append(contentsOf: KeyboardManager.hardcodeArticleKeyCommands())
		default:
			break
		}
		
		let globalFile = Bundle.main.path(forResource: KeyboardType.global.rawValue, ofType: "plist")!
		let globalEntries = NSArray(contentsOfFile: globalFile)! as! [[String: Any]]
		let globalCommands = globalEntries.compactMap { KeyboardManager.createKeyCommand(keyEntry: $0) }
		_keyCommands.append(contentsOf: globalCommands)

		let specificFile = Bundle.main.path(forResource: type.rawValue, ofType: "plist")!
		let specificEntries = NSArray(contentsOfFile: specificFile)! as! [[String: Any]]
		_keyCommands.append(contentsOf: specificEntries.compactMap { KeyboardManager.createKeyCommand(keyEntry: $0) } )
	}
	
	static func createKeyCommand(title: String, action: String, input: String, modifiers: UIKeyModifierFlags) -> UIKeyCommand {
		let selector = NSSelectorFromString(action)
		let keyCommand = UIKeyCommand(title: title, image: nil, action: selector, input: input, modifierFlags: modifiers, propertyList: nil, alternates: [], discoverabilityTitle: nil, attributes: [], state: .on)
		if #available(iOS 15.0, *) {
			keyCommand.wantsPriorityOverSystemBehavior = true
		}
		return keyCommand
	}
	
}

private extension KeyboardManager {
	
	static func createKeyCommand(keyEntry: [String: Any]) -> UIKeyCommand? {
		guard let input = createKeyCommandInput(keyEntry: keyEntry) else { return nil }
		let modifiers = createKeyModifierFlags(keyEntry: keyEntry)
		let action = keyEntry["action"] as! String
		
		if let title = keyEntry["title"] as? String {
			return KeyboardManager.createKeyCommand(title: title, action: action, input: input, modifiers: modifiers)
		} else {
			let keyCommand = UIKeyCommand(input: input, modifierFlags: modifiers, action: NSSelectorFromString(action))
			if #available(iOS 15.0, *) {
				keyCommand.wantsPriorityOverSystemBehavior = true
			}
			return keyCommand
		}
	}
		
	static func createKeyCommandInput(keyEntry: [String: Any]) -> String? {
		guard let key = keyEntry["key"] as? String else { return nil }
		
		switch(key) {
		case "[space]":
			return "\u{0020}"
		case "[uparrow]":
			return UIKeyCommand.inputUpArrow
		case "[downarrow]":
			return UIKeyCommand.inputDownArrow
		case "[leftarrow]":
			return UIKeyCommand.inputLeftArrow
		case "[rightarrow]":
			return UIKeyCommand.inputRightArrow
		case "[return]":
			return "\r"
		case "[enter]":
			return nil
		case "[delete]":
			return "\u{8}"
		case "[deletefunction]":
			return nil
        case "[tab]":
            return "\t"
		default:
			return key
		}
		
	}
	
	static func createKeyModifierFlags(keyEntry: [String: Any]) -> UIKeyModifierFlags {
		var flags = UIKeyModifierFlags()
		
		if keyEntry["shiftModifier"] as? Bool ?? false {
			flags.insert(.shift)
		}
		
		if keyEntry["optionModifier"] as? Bool ?? false {
			flags.insert(.alternate)
		}
		
		if keyEntry["commandModifier"] as? Bool ?? false {
			flags.insert(.command)
		}
		
		if keyEntry["controlModifier"] as? Bool ?? false {
			flags.insert(.control)
		}

		return flags
	}
	
	static func globalAuxilaryKeyCommands() -> [UIKeyCommand] {
		var keys = [UIKeyCommand]()
		
		let addNewFeedTitle = NSLocalizedString("keyboard.command.new-web-feed", comment: "New Web Feed")
		keys.append(KeyboardManager.createKeyCommand(title: addNewFeedTitle, action: "addNewFeed:", input: "n", modifiers: [.command]))

		let addNewFolderTitle = NSLocalizedString("keyboard.command.new-folder", comment: "New Folder")
		keys.append(KeyboardManager.createKeyCommand(title: addNewFolderTitle, action: "addNewFolder:", input: "n", modifiers: [.command, .shift]))

		let refreshTitle = NSLocalizedString("keyboard.command.refresh", comment: "Refresh")
		keys.append(KeyboardManager.createKeyCommand(title: refreshTitle, action: "refresh:", input: "r", modifiers: [.command]))

		let nextUnreadTitle = NSLocalizedString("keyboard.command.next-unread", comment: "Next Unread")
		keys.append(KeyboardManager.createKeyCommand(title: nextUnreadTitle, action: "nextUnread:", input: "/", modifiers: [.command]))

		let goToTodayTitle = NSLocalizedString("keyboard.command.go-to-today", comment: "Go To Today")
		keys.append(KeyboardManager.createKeyCommand(title: goToTodayTitle, action: "goToToday:", input: "1", modifiers: [.command]))

		let goToAllUnreadTitle = NSLocalizedString("keyboard.command.go-to-all-unread", comment: "Go To All Unread")
		keys.append(KeyboardManager.createKeyCommand(title: goToAllUnreadTitle, action: "goToAllUnread:", input: "2", modifiers: [.command]))

		let goToStarredTitle = NSLocalizedString("keyboard.command.go-to-starred", comment: "Go To Starred")
		keys.append(KeyboardManager.createKeyCommand(title: goToStarredTitle, action: "goToStarred:", input: "3", modifiers: [.command]))

		let gotoSettings = NSLocalizedString("keyboard.command.go-to-settings", comment: "Go To Settings")
			keys.append(KeyboardManager.createKeyCommand(title: gotoSettings, action: "goToSettings:", input: ",", modifiers: [.command]))
		
		let articleSearchTitle = NSLocalizedString("keyboard.command.article-search", comment: "Article Search")
		keys.append(KeyboardManager.createKeyCommand(title: articleSearchTitle, action: "articleSearch:", input: "f", modifiers: [.command, .alternate]))

		let markAllAsReadTitle = NSLocalizedString("keyboard.command.mark-all-as-read", comment: "Mark All as Read")
		keys.append(KeyboardManager.createKeyCommand(title: markAllAsReadTitle, action: "markAllAsRead:", input: "k", modifiers: [.command]))

		let cleanUp = NSLocalizedString("keyboard.command.clean-up", comment: "Clean Up")
		keys.append(KeyboardManager.createKeyCommand(title: cleanUp, action: "cleanUp:", input: "'", modifiers: [.command]))

		let toggleReadFeedsFilter = NSLocalizedString("keyboard.command.toggle-read-feeds-filter", comment: "Toggle Read Feeds Filter")
		keys.append(KeyboardManager.createKeyCommand(title: toggleReadFeedsFilter, action: "toggleReadFeedsFilter:", input: "f", modifiers: [.command, .shift]))

		let toggleReadArticlesFilter = NSLocalizedString("keyboard.command.toggle-read-articles-filter", comment: "Toggle Read Articles Filter")
		keys.append(KeyboardManager.createKeyCommand(title: toggleReadArticlesFilter, action: "toggleReadArticlesFilter:", input: "h", modifiers: [.command, .shift]))

		return keys
	}
	
	static func hardcodeFeedKeyCommands() -> [UIKeyCommand] {
		var keys = [UIKeyCommand]()

		let nextUpTitle = NSLocalizedString("keyboard.command.select-next-up", comment: "Select Next Up")
		keys.append(KeyboardManager.createKeyCommand(title: nextUpTitle, action: "selectNextUp:", input: UIKeyCommand.inputUpArrow, modifiers: []))

		let nextDownTitle = NSLocalizedString("keyboard.command.select-next-down", comment: "Select Next Down")
		keys.append(KeyboardManager.createKeyCommand(title: nextDownTitle, action: "selectNextDown:", input: UIKeyCommand.inputDownArrow, modifiers: []))
		
		let getFeedInfo = NSLocalizedString("keyboard.command.get-feed-info", comment: "Get Feed Info")
		keys.append(KeyboardManager.createKeyCommand(title: getFeedInfo, action: "showFeedInspector:", input: "i", modifiers: .command))

		return keys
	}
	
	static func hardcodeArticleKeyCommands() -> [UIKeyCommand] {
		var keys = [UIKeyCommand]()
		
		let openInBrowserTitle = NSLocalizedString("keyboard.command.open-in-browser", comment: "Open In Browser")
		keys.append(KeyboardManager.createKeyCommand(title: openInBrowserTitle, action: "openInBrowser:", input: UIKeyCommand.inputRightArrow, modifiers: [.command]))

		let toggleReadTitle = NSLocalizedString("keyboard.command.toggle-read-status", comment: "Toggle Read Status")
		keys.append(KeyboardManager.createKeyCommand(title: toggleReadTitle, action: "toggleRead:", input: "u", modifiers: [.command, .shift]))

		let markAboveAsReadTitle = NSLocalizedString("keyboard.command.mark-above-as-read", comment: "Mark Above as Read")
		keys.append(KeyboardManager.createKeyCommand(title: markAboveAsReadTitle, action: "markAboveAsRead:", input: "k", modifiers: [.command, .control]))

		let markBelowAsReadTitle = NSLocalizedString("keyboard.command.mark-below-as-read", comment: "Mark Below as Read")
		keys.append(KeyboardManager.createKeyCommand(title: markBelowAsReadTitle, action: "markBelowAsRead:", input: "k", modifiers: [.command, .shift]))

		let toggleStarredTitle = NSLocalizedString("keyboard.command.toggle-starred-status", comment: "Toggle Starred Status")
		keys.append(KeyboardManager.createKeyCommand(title: toggleStarredTitle, action: "toggleStarred:", input: "l", modifiers: [.command, .shift]))
		
		let findInArticleTitle = NSLocalizedString("keyboard.command.find-in-article", comment: "Find in Article")
		keys.append(KeyboardManager.createKeyCommand(title: findInArticleTitle, action: "beginFind:", input: "f", modifiers: [.command]))

		let getFeedInfo = NSLocalizedString("keyboard.command.get-feed-info", comment: "Get Feed Info")
		keys.append(KeyboardManager.createKeyCommand(title: getFeedInfo, action: "showFeedInspector:", input: "i", modifiers: .command))

		let toggleSidebar = NSLocalizedString("keyboard.command.toggle-sidebar", comment: "Toggle Sidebar")
		keys.append(KeyboardManager.createKeyCommand(title: toggleSidebar, action: "toggleSidebar:", input: "s", modifiers: [.command, .control]))

		let toggleReaderView = NSLocalizedString("keyboard.command.toggle-reader-view", comment: "Toggle Reader View")
		keys.append(KeyboardManager.createKeyCommand(title: toggleReaderView, action: "toggleReaderView:", input: "r", modifiers: [.command, .shift]))

		return keys
	}
	
}
