//
//  AdvancedPreferencesViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit

final class AdvancedPreferencesViewController: NSViewController {

	@IBOutlet var releaseBuildsButton: NSButton!
	@IBOutlet var testBuildsButton: NSButton!

	let releaseBuildsURL = Bundle.main.infoDictionary!["SUFeedURL"]! as! String
	let testBuildsURL = Bundle.main.infoDictionary!["FeedURLForTestBuilds"]! as! String
	let appcastDefaultsKey = "SUFeedURL"

	var didRegisterForNotification = false
	var wantsTestBuilds: Bool {
		get {
			return currentAppcastURL() == testBuildsURL
		}
		set {
			UserDefaults.standard.set(newValue ? testBuildsURL : releaseBuildsURL, forKey: appcastDefaultsKey)
		}
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		updateUI()
		if !didRegisterForNotification {
			NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
				Task { @MainActor in
					self?.userDefaultsDidChange()
				}
			}
			didRegisterForNotification = true
		}
	}

	@IBAction func updateTypeButtonClicked(_ sender: Any?) {
		guard let button = sender as? NSButton else {
			return
		}
		wantsTestBuilds = (button === testBuildsButton)
	}

	func userDefaultsDidChange() {
		updateUI()
	}
}

private extension AdvancedPreferencesViewController {

	func updateUI() {
		if wantsTestBuilds {
			testBuildsButton.state = .on
		}
		else {
			releaseBuildsButton.state = .on
		}
	}

	func currentAppcastURL() -> String {
		return UserDefaults.standard.string(forKey: appcastDefaultsKey) ?? ""
	}
}
