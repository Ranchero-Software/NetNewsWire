//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Account

var appDelegate: AppDelegate!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate, UnreadCountProvider {

	var window: UIWindow?

	var faviconDownloader: FaviconDownloader!
	var imageDownloader: ImageDownloader!
	var authorAvatarDownloader: AuthorAvatarDownloader!
	var feedIconDownloader: FeedIconDownloader!

	private let log = Log()

	var unreadCount = 0 {
		didSet {
			if unreadCount != oldValue {
				postUnreadCountDidChangeNotification()
			}
		}
	}
	
	override init() {
		
		super.init()
		appDelegate = self
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)

		// Initialize the AccountManager as soon as possible or it will cause problems
		// if the application is restoring preserved state.
		_ = AccountManager.shared
		
	}

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		
		// Set up the split view
		let splitViewController = window!.rootViewController as! UISplitViewController
		let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
		navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
		splitViewController.delegate = self
		
		AppDefaults.registerDefaults()
		let isFirstRun = AppDefaults.isFirstRun
		if isFirstRun {
			logDebugMessage("Is first run.")
		}
		
		let localAccount = AccountManager.shared.localAccount
		DefaultFeedsImporter.importIfNeeded(isFirstRun, account: localAccount)
		
		let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
		let faviconsFolderURL = tempDir.appendingPathComponent("Favicons")
		try! FileManager.default.createDirectory(at: faviconsFolderURL, withIntermediateDirectories: true, attributes: nil)
		faviconDownloader = FaviconDownloader(folder: faviconsFolderURL.absoluteString)
		
		let imagesFolderURL = tempDir.appendingPathComponent("Images")
		try! FileManager.default.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true, attributes: nil)
		imageDownloader = ImageDownloader(folder: imagesFolderURL.absoluteString)

		authorAvatarDownloader = AuthorAvatarDownloader(imageDownloader: imageDownloader)
		feedIconDownloader = FeedIconDownloader(imageDownloader: imageDownloader)

		DispatchQueue.main.async {
			self.unreadCount = AccountManager.shared.unreadCount
		}
		
		return true
		
	}

//	func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
//
//		let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
//		coder.encode(versionNumber, forKey: "VersionNumber")
//
//		return true
//
//	}
//
//	func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
//		if let storedVersionNumber = coder.decodeObject(forKey: "VersionNumber") as? String {
//			let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
//			if versionNumber == storedVersionNumber {
//				return true
//			}
//		}
//		return false
//	}
	
	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}

	// MARK: - Split view

	func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
	    guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
	    guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
	    if topAsDetailController.article == nil {
	        // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
	        return true
	    }
	    return false
	}

	// MARK: Notifications
	
	@objc func unreadCountDidChange(_ note: Notification) {
		if note.object is AccountManager {
			unreadCount = AccountManager.shared.unreadCount
		}
	}

	// MARK: - API
	
	func logMessage(_ message: String, type: LogItem.ItemType) {
		
		#if DEBUG
		if type == .debug {
			print("logMessage: \(message) - \(type)")
		}
		#endif
		
		let logItem = LogItem(type: type, message: message)
		log.add(logItem)
		
	}
	
	func logDebugMessage(_ message: String) {
		logMessage(message, type: .debug)
	}
	
}

