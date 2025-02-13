//
//  MainWindowController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 2/2/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit

final class MainWindowController {

	let window: UIWindow

	let rootSplitViewController: RootSplitViewController
	let sidebarViewController = SidebarViewController()
	let timelineViewController = TimelineCollectionViewController()
	let articleViewController = ArticleViewController()
	
	let coordinator: SceneCoordinator

	init() {
		let window = UIWindow(frame: UIScreen.main.bounds)
		self.window = window

		let rootSplitViewController = RootSplitViewController(
			sidebarViewController: sidebarViewController,
			timelineViewController: timelineViewController,
			articleViewController: articleViewController
		)

		self.coordinator = SceneCoordinator(rootSplitViewController: rootSplitViewController)
		rootSplitViewController.coordinator = coordinator
		rootSplitViewController.delegate = coordinator
		self.rootSplitViewController = rootSplitViewController

		sidebarViewController.delegate = self

		window.rootViewController = rootSplitViewController

		window.tintColor = AppColor.accent
		updateUserInterfaceStyle()

		window.makeKeyAndVisible()

		Task { @MainActor in
			// Ensure Feeds view shows on first run on iPad — otherwise the UI is empty.
			if UIDevice.current.userInterfaceIdiom == .pad && AppDefaults.isFirstRun {
				rootSplitViewController.show(.primary)
			}
		}
	}

	// MARK: - API

	func resetFocus() {
		coordinator.resetFocus()
	}

	func suspend() {
		coordinator.suspend()
	}

	func cleanUp(conditional: Bool) {
		coordinator.cleanUp(conditional: conditional)
	}

	func dismissIfLaunchingFromExternalAction() {
		coordinator.dismissIfLaunchingFromExternalAction()
	}

	func handle(_ response: UNNotificationResponse) {
		coordinator.handle(response)
	}
}

// MARK: - SidebarViewControllerDelegate

extension MainWindowController: SidebarViewControllerDelegate {

	func sidebarViewController(_: SidebarViewController, didSelect items: [any Item]) {
		timelineViewController.items = items
		rootSplitViewController.show(.supplementary)
	}
}

// MARK: - UISplitViewControllerDelegate


// MARK: - Private

private extension MainWindowController {

	func updateUserInterfaceStyle() {

		assert(Thread.isMainThread)

		let updatedStyle = AppDefaults.userInterfaceColorPalette.uiUserInterfaceStyle
		if window.overrideUserInterfaceStyle != updatedStyle {
			window.overrideUserInterfaceStyle = updatedStyle
		}
	}
}
