//
//  ArticleThemesManager.sqift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import RSCore
import Combine
#if canImport(AppKit)
import AppKit
#endif

public extension Notification.Name {
	static let ArticleThemeNamesDidChangeNotification = Notification.Name("ArticleThemeNamesDidChangeNotification")
	static let CurrentArticleThemeDidChangeNotification = Notification.Name("CurrentArticleThemeDidChangeNotification")
}

final class ArticleThemesManager: NSObject, NSFilePresenter, Logging, ObservableObject {

	static var shared: ArticleThemesManager!
	public let folderPath: String

	lazy var presentedItemOperationQueue = OperationQueue.main
	var presentedItemURL: URL?

	var currentThemeName: String {
		get {
			return AppDefaults.shared.currentThemeName ?? AppDefaults.defaultThemeName
		}
		set {
			if newValue != currentThemeName {
				do {
					currentTheme = try articleThemeWithThemeName(newValue)
					AppDefaults.shared.currentThemeName = newValue
					objectWillChange.send()
					updateFilePresenter()
				} catch {
					logger.error("Unable to set new theme: \(error.localizedDescription, privacy: .public)")
				}
			}
		}
	}

	lazy var currentTheme = {
		do {
			return try articleThemeWithThemeName(currentThemeName)
		} catch {
			logger.error("Unable to load theme \(self.currentThemeName): \(error.localizedDescription, privacy: .public)")
			return ArticleTheme.defaultTheme
		}
	}() {
		didSet {
			NotificationCenter.default.post(name: .CurrentArticleThemeDidChangeNotification, object: self)
			objectWillChange.send()
		}
	}

	lazy var themeNames = { buildThemeNames() }() {
		didSet {
			NotificationCenter.default.post(name: .ArticleThemeNamesDidChangeNotification, object: self)
			objectWillChange.send()
		}
	}

	init(folderPath: String) {
		self.folderPath = folderPath

		super.init()
		
		do {
			try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
		} catch {
			logger.error("Could not create folder for themes: \(error.localizedDescription, privacy: .public)")
			assertionFailure("Could not create folder for Themes.")
			abort()
		}

		#if os(macOS)
		NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: NSApplication.didBecomeActiveNotification, object: nil)
		#else
		NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
		#endif

		updateFilePresenter()
	}
	
	func presentedSubitemDidChange(at url: URL) {
		themeNames = buildThemeNames()
		do {
			currentTheme = try articleThemeWithThemeName(currentThemeName)
		} catch {
			Task { @MainActor in
				appDelegate.presentThemeImportError(error)
			}
		}
	}

	// MARK: API
	
	func themeExists(filename: String) -> Bool {
		let filenameLastPathComponent = (filename as NSString).lastPathComponent
		let toFilename = (folderPath as NSString).appendingPathComponent(filenameLastPathComponent)
		return FileManager.default.fileExists(atPath: toFilename)
	}
	
	func importTheme(filename: String) throws {
		let filenameLastPathComponent = (filename as NSString).lastPathComponent
		let toFilename = (folderPath as NSString).appendingPathComponent(filenameLastPathComponent)
		
		if FileManager.default.fileExists(atPath: toFilename) {
			try FileManager.default.removeItem(atPath: toFilename)
		}
		
		try FileManager.default.copyItem(atPath: filename, toPath: toFilename)
		objectWillChange.send()

		themeNames = buildThemeNames()
	}
	
	func articleThemeWithThemeName(_ themeName: String) throws -> ArticleTheme {
		if themeName == AppDefaults.defaultThemeName {
			return ArticleTheme.defaultTheme
		}
		
		let path: String
		let isAppTheme: Bool
		if let appThemePath = Bundle.main.url(forResource: themeName, withExtension: ArticleTheme.nnwThemeSuffix)?.path {
			path = appThemePath
			isAppTheme = true
		} else if let installedPath = pathForThemeName(themeName, folder: folderPath) {
			path = installedPath
			isAppTheme = false
		} else {
			return ArticleTheme.defaultTheme
		}
		
		return try ArticleTheme(path: path, isAppTheme: isAppTheme)
	}
	
	func themesByDeveloper() -> (builtIn: [ArticleTheme], other: [ArticleTheme]) {
		let installedProvidedThemes = themeNames.map({ try? articleThemeWithThemeName($0) }).compactMap({ $0 }).filter({ $0.isAppTheme }).sorted(by: { $0.name < $1.name }).filter({ $0.name != AppDefaults.defaultThemeName })
		
		let installedOtherThemes = themeNames.map({ try? articleThemeWithThemeName($0) }).compactMap({ $0 }).filter({ !$0.isAppTheme }).sorted(by: { $0.name < $1.name })
		
		return (installedProvidedThemes, installedOtherThemes)
	}
	
	#if os(macOS)
	func articleThemesMenu(for popUpButton: NSPopUpButton?) -> NSMenu {
		let menu = NSMenu()
		menu.autoenablesItems = false
		menu.removeAllItems()
		
		let defaultMenuItem = NSMenuItem()
		defaultMenuItem.title = ArticleTheme.defaultTheme.name
		defaultMenuItem.action = #selector(updateThemeSelection(_:))
		defaultMenuItem.state = currentTheme.name == defaultMenuItem.title ? .on : .off
		defaultMenuItem.target = self
		menu.addItem(defaultMenuItem)
		menu.addItem(NSMenuItem.separator())
		
		let rancheroHeading = NSMenuItem(title: "Built-in Themes", action: nil, keyEquivalent: "")
		rancheroHeading.attributedTitle = NSAttributedString(string: "Built-in Themes", attributes: [NSAttributedString.Key.foregroundColor : NSColor.secondaryLabelColor, NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 12)])
		rancheroHeading.isEnabled = false
		menu.addItem(rancheroHeading)
		
		let installedThemes = ArticleThemesManager.shared.themesByDeveloper()
		
		for theme in installedThemes.0 {
			let item = NSMenuItem()
			item.title = theme.name
			item.action = #selector(updateThemeSelection(_:))
			item.state = currentTheme.name == theme.name ? .on : .off
			item.target = self
			menu.addItem(item)
		}
		
		menu.addItem(NSMenuItem.separator())
		
		let thirdPartyHeading = NSMenuItem(title: "Other Themes", action: nil, keyEquivalent: "")
		thirdPartyHeading.attributedTitle = NSAttributedString(string: "Other Themes", attributes: [NSAttributedString.Key.foregroundColor : NSColor.secondaryLabelColor, NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 12)])
		thirdPartyHeading.isEnabled = false
		menu.addItem(thirdPartyHeading)
		
		for theme in installedThemes.1 {
			let item = NSMenuItem()
			item.title = theme.name
			item.action = #selector(updateThemeSelection(_:))
			item.state = currentTheme.name == theme.name ? .on : .off
			item.target = self
			menu.addItem(item)
		}
		popUpButton?.selectItem(withTitle: ArticleThemesManager.shared.currentThemeName)
		if popUpButton?.indexOfSelectedItem == -1 {
			popUpButton?.selectItem(withTitle: ArticleTheme.defaultTheme.name)
		}
		return menu
	}
	
	@objc
	func updateThemeSelection(_ menuItem: NSMenuItem) {
		currentThemeName = menuItem.title
	}
	
	#endif

	func deleteTheme(themeName: String) {
		if let filename = pathForThemeName(themeName, folder: folderPath) {
			try? FileManager.default.removeItem(atPath: filename)
			themeNames = buildThemeNames()
		}
	}
	
}

// MARK : Private

private extension ArticleThemesManager {
	
	@objc func applicationDidBecomeActive(_ note: Notification) {
		themeNames = buildThemeNames()
	}

	func updateFilePresenter() {
		guard let currentThemePath = currentTheme.path else {
			return
		}
		NSFileCoordinator.removeFilePresenter(self)
		presentedItemURL = URL(fileURLWithPath: currentThemePath)
		NSFileCoordinator.addFilePresenter(self)
	}

	func buildThemeNames() -> [String] {
		let appThemeFilenames = Bundle.main.paths(forResourcesOfType: ArticleTheme.nnwThemeSuffix, inDirectory: nil)
		let appThemeNames = Set(appThemeFilenames.map { ArticleTheme.themeNameForPath($0) })

		let installedThemeNames = Set(allThemePaths(folderPath).map { ArticleTheme.themeNameForPath($0) })

		let allThemeNames = appThemeNames.union(installedThemeNames)
		
		return allThemeNames.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending })
	}

	func allThemePaths(_ folder: String) -> [String] {
		let filepaths = FileManager.default.filePaths(inFolder: folder)
		return filepaths?.filter { $0.hasSuffix(ArticleTheme.nnwThemeSuffix) } ?? []
	}

	func pathForThemeName(_ themeName: String, folder: String) -> String? {
		for onePath in allThemePaths(folder) {
			if ArticleTheme.pathIsPathForThemeName(themeName, path: onePath) {
				return onePath
			}
		}
		return nil
	}
	
}
