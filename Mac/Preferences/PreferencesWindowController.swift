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
	static let Advanced = "Advanced"
	static let Ollama = "Ollama"
}

final class PreferencesWindowController: NSWindowController, NSToolbarDelegate {

	private let windowWidth = CGFloat(512.0) // Width is constant for all views; only the height changes
	private var viewControllers = [String: NSViewController]()
	private let toolbarItemSpecs: [PreferencesToolbarItemSpec] = {
		var specs = [PreferencesToolbarItemSpec]()
		specs += [PreferencesToolbarItemSpec(identifierRawValue: ToolbarItemIdentifier.General,
											 name: NSLocalizedString("General", comment: "Preferences"),
											 image: Assets.Images.preferencesToolbarGeneral)]
		specs += [PreferencesToolbarItemSpec(identifierRawValue: ToolbarItemIdentifier.Accounts,
											 name: NSLocalizedString("Accounts", comment: "Preferences"),
											 image: Assets.Images.preferencesToolbarAccounts)]
		specs += [PreferencesToolbarItemSpec(identifierRawValue: ToolbarItemIdentifier.Advanced,
											 name: NSLocalizedString("Advanced", comment: "Preferences"),
											 image: Assets.Images.preferencesToolbarAdvanced)]
		specs += [PreferencesToolbarItemSpec(identifierRawValue: ToolbarItemIdentifier.Ollama,
											 name: NSLocalizedString("Translation", comment: "Preferences"),
											 image: NSImage(systemSymbolName: "globe", accessibilityDescription: nil))]
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
		} else {
			window!.contentView?.addSubview(newViewController.view)
		}

		window!.makeFirstResponder(newViewController.view)
	}

	func viewController(identifier: String) -> NSViewController? {
		if let cachedViewController = viewControllers[identifier] {
			return cachedViewController
		}

		if identifier == ToolbarItemIdentifier.Ollama {
			let viewController = OllamaPreferencesViewController()
			viewControllers[identifier] = viewController
			return viewController
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

		let deltaHeight = contentViewFrame.height - viewFrame.height
		let heightForWindow = windowFrame.height - deltaHeight
		let windowOriginY = windowFrame.minY + deltaHeight

		var updatedWindowFrame = windowFrame
		updatedWindowFrame.size.height = heightForWindow
		updatedWindowFrame.origin.y = windowOriginY
		updatedWindowFrame.size.width = windowWidth // NSWidth(viewFrame)

		var updatedViewFrame = viewFrame
		updatedViewFrame.origin = NSPoint.zero
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

final class OllamaPreferencesViewController: NSViewController {
	
	private let baseURLTextField = NSTextField()
	private let modelTextField = NSTextField()
	private let languageTextField = NSTextField()
	private let autoTranslateCheckbox = NSButton(checkboxWithTitle: NSLocalizedString("Auto-Translate Articles", comment: ""), target: nil, action: nil)
	private let preloadCountTextField = NSTextField()
	
	init() {
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func loadView() {
		self.view = NSView(frame: NSRect(x: 0, y: 0, width: 512, height: 250))
		
		let stackView = NSStackView()
		stackView.orientation = .vertical
		stackView.alignment = .leading
		stackView.spacing = 16
		stackView.edgeInsets = NSEdgeInsets(top: 20, left: 40, bottom: 20, right: 40)
		stackView.translatesAutoresizingMaskIntoConstraints = false
		
		self.view.addSubview(stackView)
		NSLayoutConstraint.activate([
			stackView.topAnchor.constraint(equalTo: view.topAnchor),
			stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
		
		func addFormRow(title: String, control: NSView) {
			let rowStack = NSStackView()
			rowStack.orientation = .horizontal
			rowStack.alignment = .firstBaseline
			rowStack.spacing = 8
			
			let label = NSTextField(labelWithString: title)
			label.alignment = .right
			label.widthAnchor.constraint(equalToConstant: 120).isActive = true
			
			rowStack.addArrangedSubview(label)
			rowStack.addArrangedSubview(control)
			stackView.addArrangedSubview(rowStack)
		}
		
		// Base URL
		baseURLTextField.translatesAutoresizingMaskIntoConstraints = false
		baseURLTextField.widthAnchor.constraint(equalToConstant: 250).isActive = true
		baseURLTextField.stringValue = UserDefaults.standard.string(forKey: "OllamaBaseURL") ?? "http://localhost:11434/api"
		addFormRow(title: NSLocalizedString("Base URL:", comment: ""), control: baseURLTextField)
		
		// Model
		modelTextField.translatesAutoresizingMaskIntoConstraints = false
		modelTextField.widthAnchor.constraint(equalToConstant: 250).isActive = true
		modelTextField.stringValue = UserDefaults.standard.string(forKey: "OllamaModel") ?? "llama3"
		addFormRow(title: NSLocalizedString("Model:", comment: ""), control: modelTextField)
		
		// Language
		languageTextField.translatesAutoresizingMaskIntoConstraints = false
		languageTextField.widthAnchor.constraint(equalToConstant: 250).isActive = true
		languageTextField.stringValue = UserDefaults.standard.string(forKey: "OllamaPreferredLanguage") ?? "Chinese"
		addFormRow(title: NSLocalizedString("Target Language:", comment: ""), control: languageTextField)

		// Preload Count
		preloadCountTextField.translatesAutoresizingMaskIntoConstraints = false
		preloadCountTextField.widthAnchor.constraint(equalToConstant: 100).isActive = true
		preloadCountTextField.stringValue = String(UserDefaults.standard.integer(forKey: "OllamaPreloadCount"))
		if preloadCountTextField.stringValue == "0" {
			preloadCountTextField.stringValue = "10"
			UserDefaults.standard.set(10, forKey: "OllamaPreloadCount")
		}
		addFormRow(title: NSLocalizedString("Preload Next:", comment: ""), control: preloadCountTextField)
		
		// Auto-Translate
		autoTranslateCheckbox.state = UserDefaults.standard.bool(forKey: "OllamaAutoTranslate") ? .on : .off
		
		let checkboxContainer = NSStackView()
		checkboxContainer.orientation = .horizontal
		let spacer = NSView()
		spacer.translatesAutoresizingMaskIntoConstraints = false
		spacer.widthAnchor.constraint(equalToConstant: 120 + 8).isActive = true // Label width + spacing
		checkboxContainer.addArrangedSubview(spacer)
		checkboxContainer.addArrangedSubview(autoTranslateCheckbox)
		stackView.addArrangedSubview(checkboxContainer)
		
		// Targets/Actions
		baseURLTextField.target = self
		baseURLTextField.action = #selector(baseURLChanged(_:))
		
		modelTextField.target = self
		modelTextField.action = #selector(modelChanged(_:))
		
		languageTextField.target = self
		languageTextField.action = #selector(languageChanged(_:))
		
		preloadCountTextField.target = self
		preloadCountTextField.action = #selector(preloadCountChanged(_:))
		
		autoTranslateCheckbox.target = self
		autoTranslateCheckbox.action = #selector(autoTranslateChanged(_:))
	}
	
	@objc private func baseURLChanged(_ sender: NSTextField) {
		UserDefaults.standard.set(sender.stringValue, forKey: "OllamaBaseURL")
	}
	
	@objc private func modelChanged(_ sender: NSTextField) {
		UserDefaults.standard.set(sender.stringValue, forKey: "OllamaModel")
	}
	
	@objc private func languageChanged(_ sender: NSTextField) {
		UserDefaults.standard.set(sender.stringValue, forKey: "OllamaPreferredLanguage")
	}
	
	@objc private func preloadCountChanged(_ sender: NSTextField) {
		let value = max(0, min(50, sender.integerValue))
		UserDefaults.standard.set(value, forKey: "OllamaPreloadCount")
		sender.stringValue = String(value)
	}
	
	@objc private func autoTranslateChanged(_ sender: NSButton) {
		UserDefaults.standard.set(sender.state == .on, forKey: "OllamaAutoTranslate")
		NotificationCenter.default.post(name: Notification.Name("OllamaAutoTranslateDidChange"), object: nil)
	}
}
