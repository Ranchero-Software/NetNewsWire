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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	
    var window: UIWindow?
	var coordinator = SceneCoordinator()
	
    // UIWindowScene delegate
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		
		window = UIWindow(windowScene: scene as! UIWindowScene)
		window!.tintColor = AppAssets.primaryAccentColor
		updateUserInterfaceStyle()
		window!.rootViewController = coordinator.start(for: window!.frame.size)

		coordinator.restoreWindowState(session.stateRestorationActivity)
		
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
		
		if let shortcutItem = connectionOptions.shortcutItem {
			window!.makeKeyAndVisible()
			handleShortcutItem(shortcutItem)
			return
		}
		
		if let notificationResponse = connectionOptions.notificationResponse {
			window!.makeKeyAndVisible()
			coordinator.handle(notificationResponse)
			return
		}
		
        if let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity {
			coordinator.handle(userActivity)
        }
		
		window!.makeKeyAndVisible()
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
		if #available(iOS 14, *) {
			WidgetDataEncoder.encodeWidgetData()
		}
		ArticleStringFormatter.emptyCaches()
		appDelegate.prepareAccountsForBackground()
	}
	
	func sceneWillEnterForeground(_ scene: UIScene) {
		appDelegate.resumeDatabaseProcessingIfNecessary()
		appDelegate.prepareAccountsForForeground()
		coordinator.configurePanelMode(for: window!.frame.size)
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
	
	func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		DispatchQueue.main.async {
			for context in URLContexts {
				// Show Unread View or Article
				if context.url.absoluteString.contains(WidgetDeepLink.unread.url.absoluteString) {
					guard let comps = URLComponents(string: context.url.absoluteString ) else { return  }
					let id = comps.queryItems?.first(where: { $0.name == "id" })?.value
					if id != nil {
						if AccountManager.shared.isSuspended {
							AccountManager.shared.resumeAll()
						}
						self.coordinator.selectFeed(SmartFeedsController.shared.unreadFeed, completion: {
							self.coordinator.selectArticleInCurrentFeed(id!)
						})
					} else {
						self.coordinator.selectAllUnreadFeed()
					}
				}
				
				// Show Today View or Article
				if context.url.absoluteString.contains(WidgetDeepLink.today.url.absoluteString) {
					guard let comps = URLComponents(string: context.url.absoluteString ) else { return  }
					let id = comps.queryItems?.first(where: { $0.name == "id" })?.value
					if id != nil {
						if AccountManager.shared.isSuspended {
							AccountManager.shared.resumeAll()
						}
						self.coordinator.selectFeed(SmartFeedsController.shared.todayFeed, completion: {
							self.coordinator.selectArticleInCurrentFeed(id!)
						})
					} else {
						self.coordinator.selectTodayFeed()
					}
				}
				
				// Show Starred View or Article
				if context.url.absoluteString.contains(WidgetDeepLink.starred.url.absoluteString) {
					guard let comps = URLComponents(string: context.url.absoluteString ) else { return  }
					let id = comps.queryItems?.first(where: { $0.name == "id" })?.value
					if id != nil {
						if AccountManager.shared.isSuspended {
							AccountManager.shared.resumeAll()
						}
						self.coordinator.selectFeed(SmartFeedsController.shared.starredFeed, completion: {
							self.coordinator.selectArticleInCurrentFeed(id!)
						})
					} else {
						self.coordinator.selectStarredFeed()
					}
				}
				
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
	
	@objc func userDefaultsDidChange() {
		updateUserInterfaceStyle()
	}
	
	func updateUserInterfaceStyle() {
		DispatchQueue.main.async {
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
	
}
