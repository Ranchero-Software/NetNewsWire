//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import UserNotifications
import Account

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	
	var window: UIWindow?
	var coordinator: SceneCoordinator!
	
	// UIWindowScene delegate
	
	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		
		window!.tintColor = AppAssets.primaryAccentColor
		UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBarAppearance()
		
		let rootViewController = window!.rootViewController as! RootSplitViewController
		rootViewController.presentsWithGesture = true
		rootViewController.showsSecondaryOnlyButton = true
		rootViewController.preferredDisplayMode = .oneBesideSecondary

		Task { @MainActor in
			// Ensure Feeds view shows on first run on iPad — otherwise the UI is empty.
			if UIDevice.current.userInterfaceIdiom == .pad && AppDefaults.shared.isFirstRun {
				rootViewController.show(.primary)
			}
		}

		coordinator = SceneCoordinator(rootSplitViewController: rootViewController)
		rootViewController.coordinator = coordinator
		rootViewController.delegate = coordinator
		
		coordinator.restoreWindowState(activity: session.stateRestorationActivity)

		updateUserInterfaceStyle()

		NotificationCenter.default.addObserver(self, selector: #selector(handleUserInterfaceColorPaletteDidUpdate(_:)), name: .userInterfaceColorPaletteDidUpdate, object: AppDefaults.self)

		if let _ = connectionOptions.urlContexts.first?.url  {
			self.scene(scene, openURLContexts: connectionOptions.urlContexts)
			return
		}
		
		if let shortcutItem = connectionOptions.shortcutItem {
			handleShortcutItem(shortcutItem)
			return
		}
		
		if let notificationResponse = connectionOptions.notificationResponse {
			coordinator.handle(notificationResponse)
			return
		}

		// Handle activities from external sources (Handoff, Spotlight, Siri Shortcuts).
		// Skip handling session.stateRestorationActivity since UserDefaults now handles state restoration.
		if let userActivity = connectionOptions.userActivities.first {
			coordinator.handle(userActivity)
		}

	}
	
	func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
		appDelegate.resumeDatabaseProcessingIfNecessary()
		handleShortcutItem(shortcutItem)
		completionHandler(true)
	}
	
	func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
		appDelegate.resumeDatabaseProcessingIfNecessary()
		coordinator.handle(userActivity)
	}
	
	func sceneDidEnterBackground(_ scene: UIScene) {
		ArticleStringFormatter.emptyCaches()
		appDelegate.prepareAccountsForBackground()
	}

	func sceneWillEnterForeground(_ scene: UIScene) {
		appDelegate.resumeDatabaseProcessingIfNecessary()
		appDelegate.prepareAccountsForForeground()
		coordinator.resetFocus()
	}
	
	func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
		return coordinator.stateRestorationActivity
	}
	
	// API
	
	func handle(_ response: UNNotificationResponse) {
		appDelegate.resumeDatabaseProcessingIfNecessary()
		coordinator.handle(response)
	}
	
	func suspend() {
		coordinator.suspend()
	}
	
	func cleanUp(conditional: Bool) {
		coordinator.cleanUp(conditional: conditional)
	}
	
	// Handle Opening of URLs
	
	func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
		guard let context = urlContexts.first else { return }
		
		DispatchQueue.main.async {
			
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				self.coordinator.dismissIfLaunchingFromExternalAction()
			}
			
			let urlString = context.url.absoluteString
			
			// Handle the feed: and feeds: schemes
			if urlString.starts(with: "feed:") || urlString.starts(with: "feeds:") {
				let normalizedURLString = urlString.normalizedURL
				if normalizedURLString.mayBeURL {
					self.coordinator.showAddWebFeed(initialFeed: normalizedURLString, initialFeedName: nil)
				}
			}
			
			// Show Unread View or Article
			if urlString.contains(WidgetDeepLink.unread.url.absoluteString) {
				guard let comps = URLComponents(string: urlString ) else { return  }
				let id = comps.queryItems?.first(where: { $0.name == "id" })?.value
				if id != nil {
					if AccountManager.shared.isSuspended {
						AccountManager.shared.resumeAll()
					}
					self.coordinator.selectAllUnreadFeed() {
						self.coordinator.selectArticleInCurrentFeed(id!)
					}
				} else {
					self.coordinator.selectAllUnreadFeed()
				}
			}
			
			// Show Today View or Article
			if urlString.contains(WidgetDeepLink.today.url.absoluteString) {
				guard let comps = URLComponents(string: urlString ) else { return  }
				let id = comps.queryItems?.first(where: { $0.name == "id" })?.value
				if id != nil {
					if AccountManager.shared.isSuspended {
						AccountManager.shared.resumeAll()
					}
					self.coordinator.selectTodayFeed() {
						self.coordinator.selectArticleInCurrentFeed(id!)
					}
				} else {
					self.coordinator.selectTodayFeed()
				}
			}
			
			// Show Starred View or Article
			if urlString.contains(WidgetDeepLink.starred.url.absoluteString) {
				guard let comps = URLComponents(string: urlString ) else { return  }
				let id = comps.queryItems?.first(where: { $0.name == "id" })?.value
				if id != nil {
					if AccountManager.shared.isSuspended {
						AccountManager.shared.resumeAll()
					}
					self.coordinator.selectStarredFeed() {
						self.coordinator.selectArticleInCurrentFeed(id!)
					}
				} else {
					self.coordinator.selectStarredFeed()
				}
			}
			
			let filename = context.url.standardizedFileURL.path
			if filename.hasSuffix(ArticleTheme.nnwThemeSuffix) {
				self.coordinator.importTheme(filename: filename)
				return
			}
			
			// Handle theme URLs: netnewswire://theme/add?url={url}
			guard let comps = URLComponents(url: context.url, resolvingAgainstBaseURL: false),
				  "theme" == comps.host,
				 let queryItems = comps.queryItems else {
				return
			}
			
			if let providedThemeURL = queryItems.first(where: { $0.name == "url" })?.value {
				if let themeURL = URL(string: providedThemeURL) {
					let request = URLRequest(url: themeURL)
			
					DispatchQueue.main.async {
						NotificationCenter.default.post(name: .didBeginDownloadingTheme, object: nil)
					}
					let task = URLSession.shared.downloadTask(with: request) { location, response, error in
						guard
							  let location = location else { return }
						
						do {
							try ArticleThemeDownloader.shared.handleFile(at: location)
						} catch {
							NotificationCenter.default.post(name: .didFailToImportThemeWithError, object: nil, userInfo: ["error": error])
						}
					}
					task.resume()
				} else {
					print("No theme URL")
					return
				}
			} else {
				return
			}
			
			
		}
	}
}

private extension SceneDelegate {
	
	func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
		switch shortcutItem.type {
		case "com.ranchero.NetNewsWire.FirstUnread":
			coordinator.selectFirstUnreadInAllUnread()
		case "com.ranchero.NetNewsWire.ShowSearch":
			coordinator.showSearch()
		case "com.ranchero.NetNewsWire.ShowAdd":
			coordinator.showAddWebFeed()
		default:
			break
		}
	}

	@objc func handleUserInterfaceColorPaletteDidUpdate(_ notification: Notification) {
		assert(Thread.isMainThread)
		Task {
			updateUserInterfaceStyle()
		}
	}

	@MainActor func updateUserInterfaceStyle() {
		switch AppDefaults.userInterfaceColorPalette {
		case .automatic:
			self.window?.overrideUserInterfaceStyle = .unspecified
		case .light:
			self.window?.overrideUserInterfaceStyle = .light
		case .dark:
			self.window?.overrideUserInterfaceStyle = .dark
		}
	}
}
