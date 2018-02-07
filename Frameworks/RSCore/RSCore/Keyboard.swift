//
//  Keyboard.swift
//  RSCore
//
//  Created by Brent Simmons on 12/19/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import AppKit

// To get, for instance, the keyboard integer value for "\r": "\r".keyboardIntegerValue (returns 13)

public struct KeyboardConstant {

	public static let lineFeedKey = "\n".keyboardIntegerValue
	public static let returnKey = "\r".keyboardIntegerValue
	public static let spaceKey = " ".keyboardIntegerValue
}

public extension String {

	public var keyboardIntegerValue: Int {
		return Int(utf16[utf16.startIndex])
	}
}

public struct KeyboardShortcut: Hashable {

	public let key: KeyboardKey
	public let actionString: String
	public let hashValue: Int

	public init?(dictionary: [String: Any]) {

		guard let key = KeyboardKey(dictionary: dictionary) else {
			return nil
		}
		guard let actionString = dictionary["action"] as? String else {
			return nil
		}

		self.key = key
		self.actionString = actionString
		self.hashValue = key.hashValue + self.actionString.hashValue
	}

	public func perform(with view: NSView) {

		let action = NSSelectorFromString(actionString)
		NSApplication.shared.sendAction(action, to: nil, from: view)
	}

	public static func findMatchingShortcut(in shortcuts: Set<KeyboardShortcut>, key: KeyboardKey) -> KeyboardShortcut? {

		for shortcut in shortcuts {
			if shortcut.key == key {
				return shortcut
			}
		}
		return nil
	}

	public static func ==(lhs: KeyboardShortcut, rhs: KeyboardShortcut) -> Bool {

		return lhs.hashValue == rhs.hashValue && lhs.key == rhs.key && lhs.actionString == rhs.actionString
	}
}

public struct KeyboardKey: Hashable {

	public let shiftKeyDown: Bool
	public let optionKeyDown: Bool
	public let commandKeyDown: Bool
	public let controlKeyDown: Bool
	public let integerValue: Int // unmodified character as Int

	public var isModified: Bool {
		return !shiftKeyDown && !optionKeyDown && !commandKeyDown && !controlKeyDown
	}

	public var hashValue: Int {
		return integerValue
	}

	init(integerValue: Int, shiftKeyDown: Bool, optionKeyDown: Bool, commandKeyDown: Bool, controlKeyDown: Bool) {

		self.integerValue = integerValue

		self.shiftKeyDown = shiftKeyDown
		self.optionKeyDown = optionKeyDown
		self.commandKeyDown = commandKeyDown
		self.controlKeyDown = controlKeyDown
	}

	public init(with event: NSEvent) {

		let flags = event.modifierFlags
		let shiftKeyDown = flags.contains(.shift)
		let optionKeyDown = flags.contains(.option)
		let commandKeyDown = flags.contains(.command)
		let controlKeyDown = flags.contains(.control)

		let integerValue = event.charactersIgnoringModifiers?.keyboardIntegerValue ?? 0

		self.init(integerValue: integerValue, shiftKeyDown: shiftKeyDown, optionKeyDown: optionKeyDown, commandKeyDown: commandKeyDown, controlKeyDown: controlKeyDown)
	}


	public init?(dictionary: [String: Any]) {

		guard let s = dictionary["key"] as? String else {
			return nil
		}

		var integerValue = 0

		switch(s) {
		case "[space]":
			integerValue = " ".keyboardIntegerValue
		case "[uparrow]":
			integerValue = NSUpArrowFunctionKey
		case "[downarrow]":
			integerValue = NSDownArrowFunctionKey
		case "[leftarrow]":
			integerValue = NSLeftArrowFunctionKey
		case "[rightarrow]":
			integerValue = NSRightArrowFunctionKey
		case "[return]":
			integerValue = NSCarriageReturnCharacter
		case "[enter]":
			integerValue = NSEnterCharacter
		case "[delete]":
			integerValue = Int(kDeleteKeyCode)
		case "[deletefunction]":
			integerValue = NSDeleteFunctionKey
		default:
			integerValue = s.keyboardIntegerValue
		}

		let shiftKeyDown = dictionary["shiftModifier"] as? Bool ?? false
		let optionKeyDown = dictionary["optionModifier"] as? Bool ?? false
		let commandKeyDown = dictionary["commandModifier"] as? Bool ?? false
		let controlKeyDown = dictionary["controlModifier"] as? Bool ?? false

		self.init(integerValue: integerValue, shiftKeyDown: shiftKeyDown, optionKeyDown: optionKeyDown, commandKeyDown: commandKeyDown, controlKeyDown: controlKeyDown)
	}

	public static func ==(lhs: KeyboardKey, rhs: KeyboardKey) -> Bool {

		return lhs.integerValue == rhs.integerValue && lhs.shiftKeyDown == rhs.shiftKeyDown && lhs.optionKeyDown == rhs.optionKeyDown && lhs.commandKeyDown == rhs.commandKeyDown && lhs.controlKeyDown == rhs.controlKeyDown
	}
}
