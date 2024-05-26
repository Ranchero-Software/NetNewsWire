//
//  Keyboard.swift
//  RSCore
//
//  Created by Brent Simmons on 12/19/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

#if os(macOS)

import AppKit

private extension String {

	var keyboardIntegerValue: Int? {
		if isEmpty {
			return nil
		}
		let utf16String = utf16
		let startIndex = utf16String.startIndex
		if startIndex == utf16String.endIndex {
			return nil
		}
		return Int(utf16String[startIndex])
	}
}

@MainActor public struct KeyboardShortcut: Hashable {

	public let key: KeyboardKey
	public let actionString: String

	public init?(dictionary: [String: Any]) {

		guard let key = KeyboardKey(dictionary: dictionary) else {
			return nil
		}
		guard let actionString = dictionary["action"] as? String else {
			return nil
		}

		self.key = key
		self.actionString = actionString
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

	// MARK: - Hashable

	nonisolated public func hash(into hasher: inout Hasher) {
		hasher.combine(key)
	}
}

public struct KeyboardKey: Hashable, Sendable {

	public let shiftKeyDown: Bool
	public let optionKeyDown: Bool
	public let commandKeyDown: Bool
	public let controlKeyDown: Bool
	public let integerValue: Int // unmodified character as Int

	init(integerValue: Int, shiftKeyDown: Bool, optionKeyDown: Bool, commandKeyDown: Bool, controlKeyDown: Bool) {

		self.integerValue = integerValue

		self.shiftKeyDown = shiftKeyDown
		self.optionKeyDown = optionKeyDown
		self.commandKeyDown = commandKeyDown
		self.controlKeyDown = controlKeyDown
	}

	static let deleteKeyCode = 127

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
			integerValue = " ".keyboardIntegerValue!
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
			integerValue = KeyboardKey.deleteKeyCode
		case "[deletefunction]":
			integerValue = NSDeleteFunctionKey
        case "[tab]":
            integerValue = NSTabCharacter
		default:
			guard let unwrappedIntegerValue = s.keyboardIntegerValue else {
				return nil
			}
			integerValue = unwrappedIntegerValue
		}

		let shiftKeyDown = dictionary["shiftModifier"] as? Bool ?? false
		let optionKeyDown = dictionary["optionModifier"] as? Bool ?? false
		let commandKeyDown = dictionary["commandModifier"] as? Bool ?? false
		let controlKeyDown = dictionary["controlModifier"] as? Bool ?? false

		self.init(integerValue: integerValue, shiftKeyDown: shiftKeyDown, optionKeyDown: optionKeyDown, commandKeyDown: commandKeyDown, controlKeyDown: controlKeyDown)
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(integerValue)
	}
}

#endif
