//
//  AccountDefaults.swift
//  Account
//
//  Created by Brent Simmons on 7/18/20.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//

import Foundation

struct AccountDefaults {

	enum Key {
		static let performedApril2020RetentionPolicyChangeKey = "performedApril2020RetentionPolicyChange"
	}

	var performedApril2020RetentionPolicyChange: Bool {
		get {
			return UserDefaults.standard.bool(forKey: Key.performedApril2020RetentionPolicyChangeKey)
		}
		set {
			UserDefaults.standard.set(newValue, forKey: Key.performedApril2020RetentionPolicyChangeKey)
		}
	}
}

