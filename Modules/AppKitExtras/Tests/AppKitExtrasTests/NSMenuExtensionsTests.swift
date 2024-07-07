//
//  NSMenuExtensionsTests.swift
//  
//
//  Created by Brent Simmons on 5/18/24.
//

#if os(macOS)

import AppKit
import XCTest
import AppKitExtras

final class NSMenuExtensionsTests: XCTestCase {

	// MARK: - Test addSeparatorIfNeeded

	func testAddSeparatorIfNeeded_NoSeparator() {

		let menu = NSMenu(title: "Test")
		menu.addItem(menuItemForTesting())
		menu.addItem(menuItemForTesting())
		menu.addSeparatorIfNeeded()

		XCTAssertTrue(menu.items.last!.isSeparatorItem)
	}

	func testAddSeparatorIfNeeded_EmptyMenu() {

		let menu = NSMenu(title: "Test")
		menu.addSeparatorIfNeeded()

		// A separator should not be added to a menu with 0 items,
		// since a menu should never start with a separator item.
		XCTAssertEqual(menu.items.count, 0)
	}

	func testAddSeparatorIfNeeded_HasSeparator() {

		let menu = NSMenu(title: "Test")
		menu.addItem(menuItemForTesting())
		menu.addItem(menuItemForTesting())
		menu.addItem(.separator())

		let menuItemsCount = menu.items.count

		XCTAssertTrue(menu.items.last!.isSeparatorItem)

		// Should not get added — last item is already separator
		menu.addSeparatorIfNeeded()
		// Make sure last item is still separator
		XCTAssertTrue(menu.items.last!.isSeparatorItem)
		// Count should be same as before calling `addSeparatorIfNeeded()`
		XCTAssertEqual(menu.items.count, menuItemsCount)
	}
}

private extension NSMenuExtensionsTests {

	private func menuItemForTesting(_ title: String = "Test NSMenuItem") -> NSMenuItem {
		NSMenuItem(title: title, action: nil, keyEquivalent: "")
	}
}

#endif
