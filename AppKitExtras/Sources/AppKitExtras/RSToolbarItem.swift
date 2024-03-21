//
//  RSToolbarItem.swift
//  RSCore
//
//  Created by Brent Simmons on 10/16/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public class RSToolbarItem: NSToolbarItem {

	override public func validate() {

		guard let view = view, let _ = view.window else {
			isEnabled = false
			return
		}
		isEnabled = isValidAsUserInterfaceItem()
	}
}

private extension RSToolbarItem {

	func isValidAsUserInterfaceItem() -> Bool {

		// Use NSValidatedUserInterfaceItem protocol rather than calling validateToolbarItem:.

		if let target = target as? NSResponder {
			return validateWithResponder(target) ?? false
		}

		var responder = view?.window?.firstResponder
		if responder == nil {
			return false
		}

		while(true) {
			if let validated = validateWithResponder(responder!) {
				return validated
			}
			responder = responder?.nextResponder
			if responder == nil {
				break
			}
		}

		if let appDelegate = NSApplication.shared.delegate {
			if let validated = validateWithResponder(appDelegate) {
				return validated
			}
		}

		return false
	}

	func validateWithResponder(_ responder: NSObjectProtocol) -> Bool? {

		guard responder.responds(to: action), let target = responder as? NSUserInterfaceValidations else {
			return nil
		}
		return target.validateUserInterfaceItem(self)
	}
}
#endif
