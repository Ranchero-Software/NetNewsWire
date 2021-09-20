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
import Zip

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
		
		if let _ = connectionOptions.urlContexts.first?.url  {
			window?.makeKeyAndVisible()
			self.scene(scene, openURLContexts: connectionOptions.urlContexts)
			return
		}
		
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
			try? WidgetDataEncoder.shared.encodeWidgetData()
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
	
	func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
		guard let context = urlContexts.first else { return }
		
		DispatchQueue.main.async {
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
					let task = URLSession.shared.downloadTask(with: request) { [weak self] location, response, error in
						guard let self = self, let location = location else { return }
						self.createDownloadDirectoryIfRequired()
						do {
							let movedFileLocation = try self.moveTheme(from: location)
							let unzippedFileLocation = try self.unzipFile(at: movedFileLocation)
							let renamedFileLocation = try self.renameFileToThemeName(at: unzippedFileLocation)
							DispatchQueue.main.async {
								NotificationCenter.default.post(name: .didEndDownloadingTheme, object: nil)
								self.coordinator.importTheme(filename: renamedFileLocation.path)
							}
						} catch {
							DispatchQueue.main.async {
								NotificationCenter.default.post(name: .didEndDownloadingThemeWithError, object: nil, userInfo: ["error" : error])
								self.showAlert(error)
							}
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
	
	// MARK: - Theme Downloader
	private func createDownloadDirectoryIfRequired() {
		let downloadDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
		try? FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true, attributes: nil)
	}
	
	private func moveTheme(from location: URL) throws -> URL {
		var downloadDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
		let tmpFileName = UUID().uuidString + ".zip"
		downloadDirectory.appendPathComponent("\(tmpFileName)")
		try FileManager.default.moveItem(at: location, to: downloadDirectory)
		return downloadDirectory
	}
	
	private func unzipFile(at location: URL) throws -> URL {
		var unzippedDir = location.deletingLastPathComponent()
		unzippedDir.appendPathComponent("newtheme.nnwtheme")
		try Zip.unzipFile(location, destination: unzippedDir, overwrite: true, password: nil, progress: nil, fileOutputHandler: nil)
		try FileManager.default.removeItem(at: location)
		return unzippedDir
	}
	
	private func renameFileToThemeName(at location: URL) throws -> URL {
		let decoder = PropertyListDecoder()
		let plistURL = URL(fileURLWithPath: location.appendingPathComponent("Info.plist").path)
		let data = try Data(contentsOf: plistURL)
		let plist = try decoder.decode(ArticleThemePlist.self, from: data)
		var renamedUnzippedDir = location.deletingLastPathComponent()
		renamedUnzippedDir.appendPathComponent(plist.name + ".nnwtheme")
		if FileManager.default.fileExists(atPath: renamedUnzippedDir.path) {
			try FileManager.default.removeItem(at: renamedUnzippedDir)
		}
		try FileManager.default.moveItem(at: location, to: renamedUnzippedDir)
		return renamedUnzippedDir
	}
	
	private func showAlert(_ error: Error) {
		let alert = UIAlertController(title: NSLocalizedString("Error", comment: "Error"),
									  message: error.localizedDescription,
									  preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: "Dismiss"), style: .cancel, handler: nil))
		self.window?.rootViewController?.present(alert, animated: true, completion: nil)
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
