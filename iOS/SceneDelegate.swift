//
//  AppDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	
    var window: UIWindow?
	var coordinator = AppCoordinator()
	
    // UIWindowScene delegate
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		window = UIWindow(windowScene: scene as! UIWindowScene)
		window!.tintColor = AppAssets.netNewsWireBlueColor
		window!.rootViewController = coordinator.start()
		window!.makeKeyAndVisible()

        if let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity {
			DispatchQueue.main.asyncAfter(deadline: .now()) {
				self.coordinator.handle(userActivity)
			}
        }
    }
	
	func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
		coordinator.handle(userActivity)
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

}
