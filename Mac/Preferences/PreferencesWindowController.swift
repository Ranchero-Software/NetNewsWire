//
//  PreferencesWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit

private struct PreferencesToolbarItemSpec {

	let identifier: NSToolbarItem.Identifier
	let name: String
	let image: NSImage?
	
	init(identifierRawValue: String, name: String, image: NSImage?) {
		self.identifier = NSToolbarItem.Identifier(identifierRawValue)
		self.name = name
		self.image = image
	}
}

private struct ToolbarItemIdentifier {
	static let General = "General"
	static let Accounts = "Accounts"
	static let Extensions = "Extensions"
	static let Advanced = "Advanced"
}

class PreferencesWindowController : NSWindowController, NSToolbarDelegate {
	
	private let windowWidth = CGFloat(512.0) // Width is constant for all views; only the height changes
	private var viewControllers = [String: NSViewController]()
	private let toolbarItemSpecs: [PreferencesToolbarItemSpec] = {
		var specs = [PreferencesToolbarItemSpec]()
		specs += [PreferencesToolbarItemSpec(identifierRawValue: ToolbarItemIdentifier.General,
											 name: NSLocalizedString("General", comment: "Preferences"),
											 image: NSImage(named: NSImage.preferencesGeneralName))]
		specs += [PreferencesToolbarItemSpec(identifierRawValue: ToolbarItemIdentifier.Accounts,
											 name: NSLocalizedString("Accounts", comment: "Preferences"),
											 image: NSImage(named: NSImage.userAccountsName))]
//		specs += [PreferencesToolbarItemSpec(identifierRawValue: ToolbarItemIdentifier.Extensions,
//											 name: NSLocalizedString("Extensions", comment: "Preferences"),
//											 image: AppAssets.extensionPreference)]

		// Omit the Advanced Preferences for now because the Software Update related functionality is
		// forbidden/non-applicable, and we can rely upon Apple to some extent for crash reports. We
		// can add back the Crash Reporter preferences when we're ready to dynamically shuffle the rest
		// of the content in this tab.
		#if !MAC_APP_STORE
			specs += [PreferencesToolbarItemSpec(identifierRawValue: ToolbarItemIdentifier.Advanced,
												 name: NSLocalizedString("Advanced", comment: "Preferences"),
												 image: NSImage(named: NSImage.advancedName))]
		#endif
		return specs
	}()

	override func windowDidLoad() {
		let toolbar = NSToolbar(identifier: NSToolbar.Identifier("PreferencesToolbar"))
		toolbar.delegate = self
		toolbar.autosavesConfiguration = false
		toolbar.allowsUserCustomization = false
		toolbar.displayMode = .iconAndLabel
		toolbar.selectedItemIdentifier = toolbarItemSpecs.first!.identifier

		window?.showsToolbarButton = false
		window?.toolbar = toolbar

		switchToViewAtIndex(0)

		window?.center()
	}

	// MARK: Actions

	@objc func toolbarItemClicked(_ sender: Any?) {
		guard let toolbarItem = sender as? NSToolbarItem else {
			return
		}
		switchToView(identifier: toolbarItem.itemIdentifier.rawValue)
	}

	// MARK: NSToolbarDelegate

	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {

		guard let toolbarItemSpec = toolbarItemSpecs.first(where: { $0.identifier.rawValue == itemIdentifier.rawValue }) else {
			return nil
		}

		let toolbarItem = NSToolbarItem(itemIdentifier: toolbarItemSpec.identifier)
		toolbarItem.action = #selector(toolbarItemClicked(_:))
		toolbarItem.target = self
		toolbarItem.label = toolbarItemSpec.name
		toolbarItem.paletteLabel = toolbarItem.label
		toolbarItem.image = toolbarItemSpec.image

		return toolbarItem
	}

	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return toolbarItemSpecs.map { $0.identifier }
	}

	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return toolbarDefaultItemIdentifiers(toolbar)
	}

	func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return toolbarDefaultItemIdentifiers(toolbar)
	}
}

private extension PreferencesWindowController {

	var currentView: NSView? {
		return window?.contentView?.subviews.first
	}

	func toolbarItemSpec(for identifier: String) -> PreferencesToolbarItemSpec? {
		return toolbarItemSpecs.first(where: { $0.identifier.rawValue == identifier })
	}

	func switchToViewAtIndex(_ index: Int) {
		let identifier = toolbarItemSpecs[index].identifier
		switchToView(identifier: identifier.rawValue)
	}

	func switchToView(identifier: String) {
		guard let toolbarItemSpec = toolbarItemSpec(for: identifier) else {
			assertionFailure("Preferences window: no toolbarItemSpec matching \(identifier).")
			return
		}

		guard let newViewController = viewController(identifier: identifier) else {
			assertionFailure("Preferences window: no view controller matching \(identifier).")
			return
		}
		
		if newViewController.view == currentView {
			return
		}

		newViewController.view.nextResponder = newViewController
		newViewController.nextResponder = window!.contentView

		window!.title = toolbarItemSpec.name

		resizeWindow(toFitView: newViewController.view)

		if let currentView = currentView {
			window!.contentView?.replaceSubview(currentView, with: newViewController.view)
		}
		else {
			window!.contentView?.addSubview(newViewController.view)
		}

		window!.makeFirstResponder(newViewController.view)
	}

	func viewController(identifier: String) -> NSViewController? {
		if let cachedViewController = viewControllers[identifier] {
			return cachedViewController
		}

		let storyboard = NSStoryboard(name: NSStoryboard.Name("Preferences"), bundle: nil)
		guard let viewController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(identifier)) as? NSViewController else {
			assertionFailure("Unknown preferences view controller: \(identifier)")
			return nil
		}

		viewControllers[identifier] = viewController
		return viewController
	}

	func resizeWindow(toFitView view: NSView) {
		let viewFrame = view.frame
		let windowFrame = window!.frame
		let contentViewFrame = window!.contentView!.frame
		
		let deltaHeight = NSHeight(contentViewFrame) - NSHeight(viewFrame)
		let heightForWindow = NSHeight(windowFrame) - deltaHeight
		let windowOriginY = NSMinY(windowFrame) + deltaHeight
		
		var updatedWindowFrame = windowFrame
		updatedWindowFrame.size.height = heightForWindow
		updatedWindowFrame.origin.y = windowOriginY
		updatedWindowFrame.size.width = windowWidth //NSWidth(viewFrame)
		
		var updatedViewFrame = viewFrame
		updatedViewFrame.origin = NSZeroPoint
		updatedViewFrame.size.width = windowWidth
		if viewFrame != updatedViewFrame {
			view.frame = updatedViewFrame
		}
		
		if windowFrame != updatedWindowFrame {
			window!.contentView?.alphaValue = 0.0
			window!.setFrame(updatedWindowFrame, display: true, animate: true)
			window!.contentView?.alphaValue = 1.0
		}
	}
}
