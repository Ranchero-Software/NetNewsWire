//
//  NSMenuItem+RSCore.swift
//  RSCore
//
//  Created by Brent Simmons on 1/5/26.
//

#if os(macOS)
import AppKit
import ObjectiveC

extension NSMenuItem {
	/// Disables all icons in all menu items.
	///
	/// Call `NSMenuItem.disableIcons` early (from AppDelegate.init is good).
	public static func disableIcons() {
		let originalSelector = #selector(getter: image)
		let nilImageSelector = #selector(returnNilInsteadOfImage)

		guard let originalMethod = class_getInstanceMethod(NSMenuItem.self, originalSelector),
			  let newMethod = class_getInstanceMethod(NSMenuItem.self, nilImageSelector) else {
			return
		}

		method_exchangeImplementations(originalMethod, newMethod)
	}

	@objc private func returnNilInsteadOfImage() -> NSImage? {
		nil
	}
}

#endif
