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
	let makeViewController: @MainActor () -> NSViewController
}

final class PreferencesWindowController: NSWindowController, NSToolbarDelegate {

	private let minimumWindowWidth = CGFloat(512.0) // Panes that need more room widen the window
	private var viewControllers = [NSToolbarItem.Identifier: NSViewController]()
	private let toolbarItemSpecs = [
		PreferencesToolbarItemSpec(identifier: NSToolbarItem.Identifier("General"),
								   name: NSLocalizedString("General", comment: "Preferences"),
								   image: Assets.Images.preferencesToolbarGeneral,
								   makeViewController: { GeneralPreferencesViewController() }),
		PreferencesToolbarItemSpec(identifier: NSToolbarItem.Identifier("Accounts"),
								   name: NSLocalizedString("Accounts", comment: "Preferences"),
								   image: Assets.Images.preferencesToolbarAccounts,
								   makeViewController: { AccountsPreferencesViewController() }),
		PreferencesToolbarItemSpec(identifier: NSToolbarItem.Identifier("Advanced"),
								   name: NSLocalizedString("Advanced", comment: "Preferences"),
								   image: Assets.Images.preferencesToolbarAdvanced,
								   makeViewController: { AdvancedPreferencesViewController() })
	]

	convenience init() {
		self.init(windowNibName: "PreferencesWindow")
	}

	override func windowDidLoad() {
		guard let window, let firstToolbarItemSpec = toolbarItemSpecs.first else {
			return
		}

		let toolbar = NSToolbar(identifier: NSToolbar.Identifier("PreferencesToolbar"))
		toolbar.delegate = self
		toolbar.autosavesConfiguration = false
		toolbar.allowsUserCustomization = false
		toolbar.displayMode = .iconAndLabel
		toolbar.selectedItemIdentifier = firstToolbarItemSpec.identifier

		window.showsToolbarButton = false
		window.toolbar = toolbar

		switchToView(for: firstToolbarItemSpec)

		window.center()
	}

	// MARK: Actions

	@objc func toolbarItemClicked(_ sender: Any?) {
		guard let toolbarItem = sender as? NSToolbarItem, let toolbarItemSpec = toolbarItemSpec(for: toolbarItem.itemIdentifier) else {
			return
		}
		switchToView(for: toolbarItemSpec)
	}

	// MARK: NSToolbarDelegate

	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		guard let toolbarItemSpec = toolbarItemSpec(for: itemIdentifier) else {
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
		toolbarItemSpecs.map { $0.identifier }
	}

	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		toolbarDefaultItemIdentifiers(toolbar)
	}

	func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		toolbarDefaultItemIdentifiers(toolbar)
	}
}

private extension PreferencesWindowController {

	var currentView: NSView? {
		window?.contentView?.subviews.first
	}

	func toolbarItemSpec(for identifier: NSToolbarItem.Identifier) -> PreferencesToolbarItemSpec? {
		toolbarItemSpecs.first { $0.identifier == identifier }
	}

	func switchToView(for toolbarItemSpec: PreferencesToolbarItemSpec) {
		guard let window, let contentView = window.contentView else {
			return
		}

		let newViewController = viewController(for: toolbarItemSpec)
		if newViewController.view == currentView {
			return
		}

		newViewController.view.nextResponder = newViewController
		newViewController.nextResponder = contentView

		window.title = toolbarItemSpec.name

		resizeWindow(toFitView: newViewController.view)

		if let currentView {
			contentView.replaceSubview(currentView, with: newViewController.view)
		} else {
			contentView.addSubview(newViewController.view)
		}

		window.makeFirstResponder(newViewController.view)
	}

	func viewController(for toolbarItemSpec: PreferencesToolbarItemSpec) -> NSViewController {
		if let cachedViewController = viewControllers[toolbarItemSpec.identifier] {
			return cachedViewController
		}

		let viewController = toolbarItemSpec.makeViewController()
		viewControllers[toolbarItemSpec.identifier] = viewController
		return viewController
	}

	func resizeWindow(toFitView view: NSView) {
		guard let window, let contentView = window.contentView else {
			return
		}

		let viewFrame = view.frame
		let windowFrame = window.frame
		let contentViewFrame = contentView.frame

		let windowWidth = max(minimumWindowWidth, viewFrame.width)
		let deltaHeight = contentViewFrame.height - viewFrame.height
		let heightForWindow = windowFrame.height - deltaHeight
		let windowOriginY = windowFrame.minY + deltaHeight

		var updatedWindowFrame = windowFrame
		updatedWindowFrame.size.height = heightForWindow
		updatedWindowFrame.origin.y = windowOriginY
		updatedWindowFrame.size.width = windowWidth

		var updatedViewFrame = viewFrame
		updatedViewFrame.origin = NSPoint.zero
		updatedViewFrame.size.width = windowWidth
		if viewFrame != updatedViewFrame {
			view.frame = updatedViewFrame
		}

		if windowFrame != updatedWindowFrame {
			contentView.alphaValue = 0.0
			window.setFrame(updatedWindowFrame, display: true, animate: true)
			contentView.alphaValue = 1.0
		}
	}
}
