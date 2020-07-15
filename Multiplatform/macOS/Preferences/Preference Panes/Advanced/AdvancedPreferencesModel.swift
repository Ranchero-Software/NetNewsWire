//
//  AdvancedPreferencesModel.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 16/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

class AdvancedPreferencesModel: ObservableObject {
	
	let releaseBuildsURL = Bundle.main.infoDictionary!["SUFeedURL"]! as! String
	let testBuildsURL = Bundle.main.infoDictionary!["FeedURLForTestBuilds"]! as! String
	let appcastDefaultsKey = "SUFeedURL"
	
	init() {
		if AppDefaults.shared.downloadTestBuilds == false {
			AppDefaults.store.setValue(releaseBuildsURL, forKey: appcastDefaultsKey)
		} else {
			AppDefaults.store.setValue(testBuildsURL, forKey: appcastDefaultsKey)
		}
	}
	
	func updateAppcast() {
		if AppDefaults.shared.downloadTestBuilds == false {
			AppDefaults.store.setValue(releaseBuildsURL, forKey: appcastDefaultsKey)
		} else {
			AppDefaults.store.setValue(testBuildsURL, forKey: appcastDefaultsKey)
		}
	}
}
