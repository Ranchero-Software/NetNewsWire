//
//  LocalAccountPreferencesViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

final class LocalAccountPreferencesViewController: NSViewController {

	private weak var account: Account?

	init(account: Account) {
		super.init(nibName: "LocalAccount", bundle: nil)
		self.account = account
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
}
