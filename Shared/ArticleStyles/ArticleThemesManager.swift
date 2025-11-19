//
//  ArticleThemesManager.sqift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Synchronization
import RSCore

public extension Notification.Name {
	static let ArticleThemeNamesDidChangeNotification = Notification.Name("ArticleThemeNamesDidChangeNotification")
	static let CurrentArticleThemeDidChangeNotification = Notification.Name("CurrentArticleThemeDidChangeNotification")
}

final class ArticleThemesManager: NSObject, NSFilePresenter, Sendable {
	static let shared = ArticleThemesManager()
	public let folderPath: String

	let presentedItemOperationQueue = OperationQueue.main // NSFilePresenter
	let presentedItemURL: URL? // NSFilePresenter

	var currentThemeName: String {
		get {
			AppDefaults.shared.currentThemeName ?? AppDefaults.defaultThemeName
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
		get {
			state.withLock { $0.currentTheme }
		}
		set {
			state.withLock { $0.currentTheme = newValue }
			NotificationCenter.default.postOnMainThread(name: .CurrentArticleThemeDidChangeNotification, object: self)
		}
	}

	var themeNames: [String] {
		get {
			state.withLock { $0.themeNames }
		}
		set {
			state.withLock { $0.themeNames = newValue }
			NotificationCenter.default.postOnMainThread(name: .ArticleThemeNamesDidChangeNotification, object: self)
		}
	}

	private struct State {
		var currentTheme = ArticleTheme.defaultTheme
		var themeNames = [AppDefaults.defaultThemeName]
	}
	private let state = Mutex(State())

	@MainActor private var didStart = false

	override init() {
		let folderPath = Platform.dataSubfolder(forApplication: nil, folderName: "Themes")!
		self.folderPath = folderPath
		self.presentedItemURL = URL(fileURLWithPath: folderPath)

		super.init()

		do {
			try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
		} catch {
			assertionFailure("Could not create folder for Themes.")
			abort()
		}
	}

	@MainActor func start() {
		guard !didStart else {
			assertionFailure("ArticlesThemesManager.start called when already started.")
			return
		}
		didStart = true

		updateThemeNames()
		updateCurrentTheme()

		NSFileCoordinator.addFilePresenter(self)
	}

	func presentedSubitemDidChange(at url: URL) {
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

	func updateThemeNames() {
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

	func defaultArticleTheme() -> ArticleTheme {
		articleThemeWithThemeName(AppDefaults.defaultThemeName)!
	}

	func updateCurrentTheme() {
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
