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

class KeyboardManager {
	
	private(set) var keyCommands: [UIKeyCommand]?
	
	init(type: KeyboardType) {
		let globalFile = Bundle.main.path(forResource: KeyboardType.global.rawValue, ofType: "plist")!
		let globalEntries = NSArray(contentsOfFile: globalFile)! as! [[String: Any]]
		keyCommands = globalEntries.compactMap { createKeyCommand(keyEntry: $0) }
		keyCommands!.append(contentsOf: globalAuxilaryKeyCommands())

		let specificFile = Bundle.main.path(forResource: type.rawValue, ofType: "plist")!
		let specificEntries = NSArray(contentsOfFile: specificFile)! as! [[String: Any]]
		keyCommands!.append(contentsOf: specificEntries.compactMap { createKeyCommand(keyEntry: $0) } )
		
		if type == .sidebar {
			keyCommands!.append(contentsOf: sidebarAuxilaryKeyCommands())
		}
	}
	
}

private extension KeyboardManager {
	
	func createKeyCommand(keyEntry: [String: Any]) -> UIKeyCommand? {
		guard let input = createKeyCommandInput(keyEntry: keyEntry) else { return nil }
		let modifiers = createKeyModifierFlags(keyEntry: keyEntry)
		let action = keyEntry["action"] as! String
		
		if let title = keyEntry["title"] as? String {
			return createKeyCommand(title: title, action: action, input: input, modifiers: modifiers)
		} else {
			return UIKeyCommand(input: input, modifierFlags: modifiers, action: NSSelectorFromString(action))
		}
	}
	
	func createKeyCommand(title: String, action: String, input: String, modifiers: UIKeyModifierFlags) -> UIKeyCommand {
		let selector = NSSelectorFromString(action)
		return UIKeyCommand(title: title, image: nil, action: selector, input: input, modifierFlags: modifiers, propertyList: nil, alternates: [], discoverabilityTitle: nil, attributes: [], state: .on)
	}
	
	func createKeyCommandInput(keyEntry: [String: Any]) -> String? {
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
	
	func createKeyModifierFlags(keyEntry: [String: Any]) -> UIKeyModifierFlags {
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
	
	func globalAuxilaryKeyCommands() -> [UIKeyCommand] {
		var keys = [UIKeyCommand]()
		
		let addNewFeedTitle = NSLocalizedString("New Feed", comment: "New Feed")
		keys.append(createKeyCommand(title: addNewFeedTitle, action: "addNewFeed:", input: "n", modifiers: [.command]))

		let addNewFolderTitle = NSLocalizedString("New Folder", comment: "New Folder")
		keys.append(createKeyCommand(title: addNewFolderTitle, action: "addNewFolder:", input: "n", modifiers: [.command, .shift]))

		let refreshTitle = NSLocalizedString("Refresh", comment: "Refresh")
		keys.append(createKeyCommand(title: refreshTitle, action: "refresh:", input: "r", modifiers: [.command]))

		let nextUnreadTitle = NSLocalizedString("Next Unread", comment: "Next Unread")
		keys.append(createKeyCommand(title: nextUnreadTitle, action: "nextUnread:", input: "/", modifiers: [.command]))

		let goToTodayTitle = NSLocalizedString("Go To Today", comment: "Go To Today")
		keys.append(createKeyCommand(title: goToTodayTitle, action: "goToToday:", input: "1", modifiers: [.command]))

		let goToAllUnreadTitle = NSLocalizedString("Go To All Unread", comment: "Go To All Unread")
		keys.append(createKeyCommand(title: goToAllUnreadTitle, action: "goToAllUnread:", input: "2", modifiers: [.command]))

		let goToStarredTitle = NSLocalizedString("Go To Starred", comment: "Go To Starred")
		keys.append(createKeyCommand(title: goToStarredTitle, action: "goToStarred:", input: "3", modifiers: [.command]))

		let toggleReadTitle = NSLocalizedString("Toggle Read Status", comment: "Toggle Read Status")
		keys.append(createKeyCommand(title: toggleReadTitle, action: "toggleRead:", input: "U", modifiers: [.command, .shift]))

		let markAllAsReadTitle = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")
		keys.append(createKeyCommand(title: markAllAsReadTitle, action: "markAllAsRead:", input: "k", modifiers: [.command]))

		let markOlderAsReadTitle = NSLocalizedString("Mark Older as Read", comment: "Mark Older as Read")
		keys.append(createKeyCommand(title: markOlderAsReadTitle, action: "markOlderArticlesAsRead:", input: "k", modifiers: [.command, .shift]))

		let toggleStarredTitle = NSLocalizedString("Toggle Starred Status", comment: "Toggle Starred Status")
		keys.append(createKeyCommand(title: toggleStarredTitle, action: "toggleStarred:", input: "l", modifiers: [.command, .shift]))

		let openInBrowserTitle = NSLocalizedString("Open In Browser", comment: "Open In Browser")
		keys.append(createKeyCommand(title: openInBrowserTitle, action: "openInBrowser:", input: UIKeyCommand.inputRightArrow, modifiers: [.command]))

		return keys
	}
	
	func sidebarAuxilaryKeyCommands() -> [UIKeyCommand] {
		var keys = [UIKeyCommand]()
		
		let nextUpTitle = NSLocalizedString("Select Next Up", comment: "Select Next Up")
		keys.append(createKeyCommand(title: nextUpTitle, action: "selectNextUp:", input: UIKeyCommand.inputUpArrow, modifiers: []))

		let nextDownTitle = NSLocalizedString("Select Next Down", comment: "Select Next Down")
		keys.append(createKeyCommand(title: nextDownTitle, action: "selectNextDown:", input: UIKeyCommand.inputDownArrow, modifiers: []))

		return keys
	}
	
}
