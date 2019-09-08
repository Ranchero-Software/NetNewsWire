//
//  Account-Extensions.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/7/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Account

extension AccountType: Identifiable {
	public var id: Int {
		return rawValue
	}
}

extension Account: Identifiable {
	public var id: String {
		return accountID
	}
}
