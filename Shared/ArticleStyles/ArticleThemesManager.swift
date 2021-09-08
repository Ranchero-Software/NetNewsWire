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

let ArticleThemeNamesDidChangeNotification = "ArticleThemeNamesDidChangeNotification"
let CurrentArticleThemeDidChangeNotification = "CurrentArticleThemeDidChangeNotification"

final class ArticleThemesManager {

	static var shared: ArticleThemesManager!
	private let folderPath: String

	var currentThemeName: String {
		get {
			return AppDefaults.shared.currentThemeName ?? AppDefaults.defaultThemeName
		}
		set {
			if newValue != currentThemeName {
				AppDefaults.shared.currentThemeName = newValue
			}
		}
	}

	var currentTheme: ArticleTheme {
		didSet {
			NotificationCenter.default.post(name: Notification.Name(rawValue: CurrentArticleThemeDidChangeNotification), object: self)
		}
	}

	var themeNames = [AppDefaults.defaultThemeName] {
		didSet {
			NotificationCenter.default.post(name: Notification.Name(rawValue: ArticleThemeNamesDidChangeNotification), object: self)
		}
	}

	init(folderPath: String) {
		self.folderPath = folderPath

		do {
			try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
		} catch {
			assertionFailure("Could not create folder for Themes.")
			abort()
		}

		currentTheme = ArticleTheme.defaultTheme

		updateThemeNames()
		updateCurrentTheme()

		#if os(macOS)
		NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: NSApplication.didBecomeActiveNotification, object: nil)
		#else
		NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
		#endif
	}

	// MARK: Notifications

	@objc dynamic func applicationDidBecomeActive(_ note: Notification) {
		updateThemeNames()
		updateCurrentTheme()
	}

	// MARK : Internal

	private func updateThemeNames() {
		let updatedThemeNames = allThemePaths(folderPath).map { ArticleTheme.themeNameForPath($0) }

		if updatedThemeNames != themeNames {
			themeNames = updatedThemeNames
		}
	}

	private func articleThemeWithThemeName(_ themeName: String) -> ArticleTheme? {
		if themeName == AppDefaults.defaultThemeName {
			return ArticleTheme.defaultTheme
		}
		
		guard let path = pathForThemeName(themeName, folder: folderPath) else {
			return nil
		}

		return ArticleTheme(path: path)
	}

	private func defaultArticleTheme() -> ArticleTheme {
		return articleThemeWithThemeName(AppDefaults.defaultThemeName)!
	}

	private func updateCurrentTheme() {
		var themeName = currentThemeName
		if !themeNames.contains(themeName) {
			themeName = AppDefaults.defaultThemeName
			currentThemeName = AppDefaults.defaultThemeName
		}

		var articleTheme = articleThemeWithThemeName(themeName)
		if articleTheme == nil {
			articleTheme = defaultArticleTheme()
			currentThemeName = AppDefaults.defaultThemeName
		}

		if let articleTheme = articleTheme, articleTheme != currentTheme {
			currentTheme = articleTheme
		}
	}

	private func allThemePaths(_ folder: String) -> [String] {
		let filepaths = FileManager.default.filePaths(inFolder: folder)
		return filepaths?.filter { $0.hasSuffix(ArticleTheme.nnwThemeSuffix) } ?? []
	}

	private func pathForThemeName(_ themeName: String, folder: String) -> String? {
		for onePath in allThemePaths(folder) {
			if ArticleTheme.pathIsPathForThemeName(themeName, path: onePath) {
				return onePath
			}
		}
		return nil
	}
	
}
