//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate, UISplitViewControllerDelegate {
    
    var window: UIWindow?
    
    // UIWindowScene delegate
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

		window!.tintColor = AppAssets.netNewsWireBlueColor

		let splitViewController = UIStoryboard.main.instantiateInitialViewController() as! UISplitViewController
		splitViewController.delegate = self
		window!.rootViewController = splitViewController
		
		let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
		navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
		
		
//        if let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity {
//            if !configure(window: window, with: userActivity) {
//                print("Failed to restore from \(userActivity)")
//            }
//        }

        // If there were no user activities, we don't have to do anything.
        // The `window` property will automatically be loaded with the storyboard's initial view controller.
    }
	
	func sceneDidEnterBackground(_ scene: UIScene) {
		appDelegate.prepareAccountsForBackground()
	}
	
	func sceneWillEnterForeground(_ scene: UIScene) {
		appDelegate.prepareAccountsForForeground()
	}
	
//    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
//        return scene.userActivity
//    }
//
    // Utilities
    
//    func configure(window: UIWindow?, with activity: NSUserActivity) -> Bool {
//        if activity.title == GalleryOpenDetailPath {
//            if let photoID = activity.userInfo?[GalleryOpenDetailPhotoIdKey] as? String {
//
//                if let photoDetailViewController = PhotoDetailViewController.loadFromStoryboard() {
//                    photoDetailViewController.photo = Photo(name: photoID)
//
//                    if let navigationController = window?.rootViewController as? UINavigationController {
//                        navigationController.pushViewController(photoDetailViewController, animated: false)
//                        return true
//                    }
//                }
//            }
//        }
//        return false
//     }

	// MARK: UISplitViewControllerDelegate
	
	func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
		guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
		guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
		if topAsDetailController.navState?.currentArticle == nil {
			// Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
			return true
		}
		return false
	}
	
}
