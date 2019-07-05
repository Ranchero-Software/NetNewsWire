//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	
	var coordinator = AppCoordinator()
	
    var window: UIWindow?
    
    // UIWindowScene delegate
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

		window!.tintColor = AppAssets.netNewsWireBlueColor
		window!.rootViewController = coordinator.start()

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

}
