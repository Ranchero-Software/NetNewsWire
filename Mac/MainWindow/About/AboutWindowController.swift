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

// MARK: - AboutWindowController

@available(macOS 12, *)
class AboutWindowController: NSWindowController, NSToolbarDelegate {
	
	var hostingController: AboutHostingController
	
	override init(window: NSWindow?) {
		self.hostingController = AboutHostingController(rootView: AnyView(AboutNetNewsWireView()))
		super.init(window: window)
		let window = NSWindow(contentViewController: hostingController)
		window.identifier = .aboutNetNewsWire
		window.standardWindowButton(.zoomButton)?.isEnabled = false
		window.titleVisibility = .hidden
		self.window = window
		self.hostingController.configureToolbar()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
	}
	
}

// MARK: - AboutHostingController

@available(macOS 12, *)
class AboutHostingController: NSHostingController<AnyView>, NSToolbarDelegate {
	
	private lazy var segmentedControl: NSSegmentedControl = {
		let control = NSSegmentedControl(labels: ["About", "Credits"],
										 trackingMode: .selectOne,
										 target: self,
										 action: #selector(segmentedControlSelectionChanged(_:)))
		control.segmentCount = 2
		control.setSelected(true, forSegment: 0)
		return control
	}()
	
	override init(rootView: AnyView) {
		super.init(rootView: rootView)
	}
	
	@MainActor required dynamic init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	public func configureToolbar() {
		let toolbar = NSToolbar(identifier: NSToolbar.Identifier("netnewswire.about.toolbar"))
		toolbar.delegate = self
		toolbar.autosavesConfiguration = false
		toolbar.allowsUserCustomization = false
		view.window?.toolbar = toolbar
		view.window?.toolbarStyle = .unified
		toolbar.insertItem(withItemIdentifier: .flexibleSpace, at: 0)
		toolbar.insertItem(withItemIdentifier: .flexibleSpace, at: 2)
	}
	
	// MARK: NSToolbarDelegate
	
	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		switch itemIdentifier {
	
		case .aboutGroup:
			let toolbarItem = NSToolbarItem(itemIdentifier: .aboutGroup)
			toolbarItem.view = segmentedControl
			toolbarItem.autovalidates = true
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
		return []
	}
	
	// MARK: - Target/Action
	@objc
	func segmentedControlSelectionChanged(_ sender: NSSegmentedControl) {
		if sender.selectedSegment == 0 {
			rootView = AnyView(AboutNetNewsWireView())
		} else {
			rootView = AnyView(CreditsNetNewsWireView())
		}
	}
	
}



