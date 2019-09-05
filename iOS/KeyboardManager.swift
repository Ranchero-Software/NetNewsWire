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
	
	private let coordinator: SceneCoordinator
	private(set) var keyCommands: [UIKeyCommand]?
	
	init(type: KeyboardType, coordinator: SceneCoordinator) {
		self.coordinator = coordinator
		load(type: type)
	}
	
}

private extension KeyboardManager {
	
	func load(type: KeyboardType) {
		let globalFile = Bundle.main.path(forResource: KeyboardType.global.rawValue, ofType: "plist")!
		let globalEntries = NSArray(contentsOfFile: globalFile)! as! [[String: Any]]
		var globalCommands = globalEntries.compactMap { createKeyCommand(keyEntry: $0) }
		
		let specificFile = Bundle.main.path(forResource: type.rawValue, ofType: "plist")!
		let specificEntries = NSArray(contentsOfFile: specificFile)! as! [[String: Any]]
		let specificCommands = specificEntries.compactMap { createKeyCommand(keyEntry: $0) }
		
		globalCommands.append(contentsOf: specificCommands)
		
		if type == .sidebar {
			globalCommands.append(contentsOf: sidebarAuxilaryKeyCommands())
		}
		
		keyCommands = globalCommands
	}
	
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
			return " "
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
	
	func sidebarAuxilaryKeyCommands() -> [UIKeyCommand] {
		var keys = [UIKeyCommand]()
		
		let nextUpTitle = NSLocalizedString("Select Next Up", comment: "Select Next Up")
		keys.append(createKeyCommand(title: nextUpTitle, action: "selectNextUp:", input: UIKeyCommand.inputUpArrow, modifiers: []))

		let nextDownTitle = NSLocalizedString("Select Next Down", comment: "Select Next Down")
		keys.append(createKeyCommand(title: nextDownTitle, action: "selectNextDown:", input: UIKeyCommand.inputDownArrow, modifiers: []))

		return keys
	}
	
}
