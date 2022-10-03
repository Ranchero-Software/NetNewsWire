//
//  AboutWindowController.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 03/10/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import AppKit
import SwiftUI
import RSCore

extension NSToolbarItem.Identifier {
	static let aboutGroup = NSToolbarItem.Identifier("about.toolbar.group")
}

extension NSUserInterfaceItemIdentifier {
	static let aboutNetNewsWire = NSUserInterfaceItemIdentifier("about.netnewswire")
}

@available(macOS 12, *)
class AboutWindowController: NSWindowController, NSToolbarDelegate {
	
	static var `default`: AboutWindowController {
		let hostingController = NSHostingController(rootView: AboutView())
		let window = NSWindow(contentViewController: hostingController)
		window.identifier = .aboutNetNewsWire
		let controller = AboutWindowController(window: window)
		controller.configure()
		return controller
	}
	
	func configure() {
		window?.title = NSLocalizedString("About", comment: "About")
		window?.titleVisibility = .hidden
		let toolbar = NSToolbar(identifier: NSToolbar.Identifier("netnewswire.about.toolbar"))
		toolbar.delegate = self
		window?.toolbar = toolbar
		window?.toolbarStyle = .unified
		toolbar.insertItem(withItemIdentifier: .flexibleSpace, at: 0)
		toolbar.insertItem(withItemIdentifier: .flexibleSpace, at: 2)
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
	}
	
	@objc
	func segmentedControlSelectionChanged(_ sender: NSSegmentedControl) {
		print(sender)
	}
	
	
	// MARK: NSToolbarDelegate
	
	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		
		switch itemIdentifier {
	
		case .aboutGroup:
			let toolbarItem: NSToolbarItem
			let group = NSToolbarItemGroup(itemIdentifier: itemIdentifier)
			
			let segmented = NSSegmentedControl(labels: ["About", "Credits"],
											   trackingMode: .selectOne,
											   target: NSApplication.shared.delegate as? AppDelegate,
											   action: #selector(AppDelegate.segmentedControlSelectionChanged(_:)))
			segmented.segmentStyle = .texturedRounded
			segmented.segmentCount = 2
			segmented.setSelected(true, forSegment: 0)
			group.view = segmented
			toolbarItem = group
			return toolbarItem
		default:
			return nil
		}
		
	}
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [.aboutGroup]
	}
	
	func toolbarWillAddItem(_ notification: Notification) {
		//
	}
	
	func toolbarDidRemoveItem(_ notification: Notification) {
		//
	}
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [.aboutGroup]
	}
	
	func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [.aboutGroup]
	}
	
	
}
