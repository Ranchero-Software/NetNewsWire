//
//  ArticlesSettingsView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/14/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI

struct ArticlesSettingsView: View {

	/// Asks the user to confirm installing the theme file they picked.
	let importTheme: (URL) throws -> Void

	@State private var model = ArticlesSettingsModel()
	@State private var themesModel = ArticleThemesModel()

	var body: some View {
		List {
			Section {
				NavigationLink {
					ArticleThemesView(importTheme: importTheme)
				} label: {
					LabeledContent(String(localized: "Theme", comment: "Theme"), value: themesModel.currentThemeName)
				}
			}
			Section(String(localized: "Behavior", comment: "Behavior")) {
				Toggle(String(localized: "Open Links in NetNewsWire", comment: "Open Links in NetNewsWire"), isOn: Binding(get: { !model.useSystemBrowser }, set: {
					AppDefaults.useSystemBrowser = !$0
					UIMenuSystem.main.setNeedsRebuild()
				}))
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
	}
}

// MARK: - ArticlesSettingsModel

/// Tracks the Articles behavior settings, updating when they change.
@MainActor @Observable final class ArticlesSettingsModel {

	private(set) var useSystemBrowser = AppDefaults.useSystemBrowser
	private(set) var isArticleContentJavascriptEnabled = AppDefaults.isArticleContentJavascriptEnabled
	private(set) var articleSwipeNavigationEnabled = AppDefaults.articleSwipeNavigationEnabled
	private(set) var articleFullscreenAvailable = AppDefaults.articleFullscreenAvailable

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(handleUseSystemBrowserDidChange(_:)), name: .useSystemBrowserDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleContentJavascriptEnabledDidChange(_:)), name: .articleContentJavascriptEnabledDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleSwipeNavigationEnabledDidChange(_:)), name: .articleSwipeNavigationEnabledDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleFullscreenAvailableDidChange(_:)), name: .articleFullscreenAvailableDidChange, object: nil)
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
