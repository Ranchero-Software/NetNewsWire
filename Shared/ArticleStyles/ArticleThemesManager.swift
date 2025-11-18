//
//  ArticleThemesManager.sqift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

public extension Notification.Name {
	static let ArticleThemeNamesDidChangeNotification = Notification.Name("ArticleThemeNamesDidChangeNotification")
	static let CurrentArticleThemeDidChangeNotification = Notification.Name("CurrentArticleThemeDidChangeNotification")
}

@MainActor final class ArticleThemesManager: NSObject, NSFilePresenter {
	static let shared = ArticleThemesManager()
	public let folderPath: String

	let presentedItemOperationQueue = OperationQueue.main // NSFilePresenter
	let presentedItemURL: URL? // NSFilePresenter

	var currentThemeName: String {
		get {
			return AppDefaults.shared.currentThemeName ?? AppDefaults.defaultThemeName
		}
		set {
			if newValue != currentThemeName {
				AppDefaults.shared.currentThemeName = newValue
				updateThemeNames()
				updateCurrentTheme()
			}
		}
	}

	var currentTheme: ArticleTheme {
		didSet {
			NotificationCenter.default.post(name: .CurrentArticleThemeDidChangeNotification, object: self)
		}
	}

	var themeNames = [AppDefaults.defaultThemeName] {
		didSet {
			NotificationCenter.default.post(name: .ArticleThemeNamesDidChangeNotification, object: self)
		}
	}

	private var didStart = false

	override init() {
		let folderPath = Platform.dataSubfolder(forApplication: nil, folderName: "Themes")!
		self.folderPath = folderPath
		self.presentedItemURL = URL(fileURLWithPath: folderPath)
		self.currentTheme = ArticleTheme.defaultTheme

		super.init()

		do {
			try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
		} catch {
			assertionFailure("Could not create folder for Themes.")
			abort()
		}
	}

	func start() {
		guard !didStart else {
			assertionFailure("ArticlesThemesManager.start called when already started.")
			return
		}
		didStart = true

		updateThemeNames()
		updateCurrentTheme()

		NSFileCoordinator.addFilePresenter(self)
	}

	nonisolated func presentedSubitemDidChange(at url: URL) {
		updateThemeNames()
		updateCurrentTheme()
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
	}

	func articleThemeWithThemeName(_ themeName: String) -> ArticleTheme? {
		if themeName == AppDefaults.defaultThemeName {
			return ArticleTheme.defaultTheme
		}

		let url: URL
		let isAppTheme: Bool
		if let appThemeURL = Bundle.main.url(forResource: themeName, withExtension: ArticleTheme.nnwThemeSuffix) {
			url = appThemeURL
			isAppTheme = true
		} else if let installedPath = pathForThemeName(themeName, folder: folderPath) {
			url = URL(fileURLWithPath: installedPath)
			isAppTheme = false
		} else {
			return nil
		}

		do {
			return try ArticleTheme(url: url, isAppTheme: isAppTheme)
		} catch {
			NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error": error])
			return nil
		}

	}

	func deleteTheme(themeName: String) {
		if let filename = pathForThemeName(themeName, folder: folderPath) {
			try? FileManager.default.removeItem(atPath: filename)
		}
	}
}

// MARK : Private

private extension ArticleThemesManager {

	nonisolated func updateThemeNames() {
		MainActor.assumeIsolated {
			let appThemeFilenames = Bundle.main.paths(forResourcesOfType: ArticleTheme.nnwThemeSuffix, inDirectory: nil)
			let appThemeNames = Set(appThemeFilenames.map { ArticleTheme.themeNameForPath($0) })

			let installedThemeNames = Set(allThemePaths(folderPath).map { ArticleTheme.themeNameForPath($0) })

			let allThemeNames = appThemeNames.union(installedThemeNames)

			let sortedThemeNames = allThemeNames.sorted(by: { $0.compare($1, options: .caseInsensitive) == .orderedAscending })
			Task { @MainActor in
				if sortedThemeNames != themeNames {
					themeNames = sortedThemeNames
				}
			}
		}
	}

	func defaultArticleTheme() -> ArticleTheme {
		articleThemeWithThemeName(AppDefaults.defaultThemeName)!
	}

	nonisolated func updateCurrentTheme() {
		MainActor.assumeIsolated {
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
	}

	nonisolated func allThemePaths(_ folder: String) -> [String] {
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
