//
//  ArticlesSettingsView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/14/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct ArticlesSettingsView: View {

	/// Asks the user to confirm installing the theme file they picked.
	let importTheme: (URL) throws -> Void

	@State private var model = ArticlesSettingsModel()
	@State private var isShowingThemeImporter = false
	@State private var isShowingDeleteThemeChoices = false
	@State private var themeNamePendingDeletion: String?

	var body: some View {
		List {
			Section(String(localized: "Themes", comment: "Themes")) {
				Picker(String(localized: "Theme", comment: "Theme"), selection: Binding(get: { model.currentThemeName }, set: { ArticleThemesManager.shared.currentThemeName = $0 })) {
					Section {
						Text(model.defaultThemeName).tag(model.defaultThemeName)
					}
					Section {
						ForEach(model.installedThemeNames, id: \.self) { themeName in
							Text(themeName).tag(themeName)
						}
					}
				}
				.pickerStyle(.menu)
				Button(String(localized: "Import Theme…", comment: "Import Theme…")) {
					isShowingThemeImporter = true
				}
				Button(String(localized: "Delete Theme…", comment: "Delete Theme…"), role: .destructive) {
					isShowingDeleteThemeChoices = true
				}
				.disabled(model.deletableThemeNames.isEmpty)
				.confirmationDialog(String(localized: "Delete Theme…", comment: "Delete Theme…"), isPresented: $isShowingDeleteThemeChoices, titleVisibility: .hidden) {
					ForEach(model.deletableThemeNames, id: \.self) { themeName in
						Button(themeName, role: .destructive) {
							themeNamePendingDeletion = themeName
						}
					}
					Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) {
					}
				}
			}
			Section(String(localized: "Behavior", comment: "Behavior")) {
				Toggle(String(localized: "Open Links in NetNewsWire", comment: "Open Links in NetNewsWire"), isOn: Binding(get: { !model.useSystemBrowser }, set: { AppDefaults.useSystemBrowser = !$0 }))
				Toggle(String(localized: "Swipe Between Articles", comment: "Swipe Between Articles"), isOn: Binding(get: { model.articleSwipeNavigationEnabled }, set: { AppDefaults.articleSwipeNavigationEnabled = $0 }))
			}
			Section {
				Toggle(String(localized: "JavaScript", comment: "JavaScript"), isOn: Binding(get: { model.isArticleContentJavascriptEnabled }, set: { AppDefaults.isArticleContentJavascriptEnabled = $0 }))
			} footer: {
				Text("Some content, such as videos and embedded social media posts, may require JavaScript to work correctly.", comment: "Some content, such as videos and embedded social media posts, may require JavaScript to work correctly.")
			}
			// Full Screen Articles is iPhone-only.
			if UIDevice.current.userInterfaceIdiom == .phone {
				Section {
					Toggle(String(localized: "Full Screen Articles", comment: "Full Screen Articles"), isOn: Binding(get: { model.articleFullscreenAvailable }, set: { AppDefaults.articleFullscreenAvailable = $0 }))
				} footer: {
					Text("Tap the article top bar to enter Full Screen. Tap the top or bottom to exit.", comment: "Tap the article top bar to enter Full Screen. Tap the top or bottom to exit.")
				}
			}
		}
		.settingsAccentTint()
		.navigationTitle(String(localized: "Articles", comment: "Articles"))
		.fileImporter(isPresented: $isShowingThemeImporter, allowedContentTypes: [.netNewsWireTheme]) { result in
			if case .success(let url) = result {
				importThemeFile(url)
			}
		}
		.alert(String(localized: "Delete Theme?", comment: "Delete Theme"), isPresented: isShowingDeleteThemeConfirmation, presenting: themeNamePendingDeletion) { themeName in
			Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) {
			}
			Button(String(localized: "Delete", comment: "Delete button"), role: .destructive) {
				ArticleThemesManager.shared.deleteTheme(themeName: themeName)
			}
		} message: { themeName in
			Text(deleteThemeMessage(themeName))
		}
	}
}

// MARK: - Private

private extension ArticlesSettingsView {

	var isShowingDeleteThemeConfirmation: Binding<Bool> {
		Binding {
			themeNamePendingDeletion != nil
		} set: { isShowing in
			if !isShowing {
				themeNamePendingDeletion = nil
			}
		}
	}

	func deleteThemeMessage(_ themeName: String) -> String {
		let localizedMessageText = NSLocalizedString("Are you sure you want to delete the theme “%@”?", comment: "Delete Theme Message")
		return NSString.localizedStringWithFormat(localizedMessageText as NSString, themeName) as String
	}

	func importThemeFile(_ url: URL) {
		guard url.startAccessingSecurityScopedResource() else {
			return
		}
		defer {
			url.stopAccessingSecurityScopedResource()
		}

		do {
			try importTheme(url)
		} catch {
			NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error": error])
		}
	}
}

// MARK: - ArticlesSettingsModel

/// Tracks the Articles settings and installed themes, updating when they change.
@MainActor @Observable final class ArticlesSettingsModel {

	let defaultThemeName = ArticleTheme.defaultTheme.name
	private(set) var currentThemeName = ArticleTheme.defaultTheme.name
	private(set) var installedThemeNames = [String]()
	/// Themes that came with the app can’t be deleted.
	private(set) var deletableThemeNames = [String]()
	private(set) var useSystemBrowser = AppDefaults.useSystemBrowser
	private(set) var isArticleContentJavascriptEnabled = AppDefaults.isArticleContentJavascriptEnabled
	private(set) var articleSwipeNavigationEnabled = AppDefaults.articleSwipeNavigationEnabled
	private(set) var articleFullscreenAvailable = AppDefaults.articleFullscreenAvailable

	init() {
		updateThemes()

		NotificationCenter.default.addObserver(self, selector: #selector(handleCurrentArticleThemeDidChange(_:)), name: .CurrentArticleThemeDidChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleThemeNamesDidChange(_:)), name: .ArticleThemeNamesDidChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleUseSystemBrowserDidChange(_:)), name: .useSystemBrowserDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleContentJavascriptEnabledDidChange(_:)), name: .articleContentJavascriptEnabledDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleSwipeNavigationEnabledDidChange(_:)), name: .articleSwipeNavigationEnabledDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleFullscreenAvailableDidChange(_:)), name: .articleFullscreenAvailableDidChange, object: nil)
	}

	@objc func handleCurrentArticleThemeDidChange(_ notification: Notification) {
		updateThemes()
	}

	@objc func handleArticleThemeNamesDidChange(_ notification: Notification) {
		updateThemes()
	}

	@objc func handleUseSystemBrowserDidChange(_ notification: Notification) {
		useSystemBrowser = AppDefaults.useSystemBrowser
	}

	@objc func handleArticleContentJavascriptEnabledDidChange(_ notification: Notification) {
		isArticleContentJavascriptEnabled = AppDefaults.isArticleContentJavascriptEnabled
	}

	@objc func handleArticleSwipeNavigationEnabledDidChange(_ notification: Notification) {
		articleSwipeNavigationEnabled = AppDefaults.articleSwipeNavigationEnabled
	}

	@objc func handleArticleFullscreenAvailableDidChange(_ notification: Notification) {
		articleFullscreenAvailable = AppDefaults.articleFullscreenAvailable
	}
}

private extension ArticlesSettingsModel {

	func updateThemes() {
		let themeNames = ArticleThemesManager.shared.themeNames
		installedThemeNames = themeNames.filter { $0 != defaultThemeName }

		let themeName = ArticleThemesManager.shared.currentThemeName
		currentThemeName = installedThemeNames.contains(themeName) ? themeName : defaultThemeName

		deletableThemeNames = themeNames.filter { themeName in
			guard let theme = ArticleThemesManager.shared.articleThemeWithThemeName(themeName) else {
				return false
			}
			return !theme.isAppTheme
		}
	}
}
