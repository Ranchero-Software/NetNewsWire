//
//  AccountsAddTableCellView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/1/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

protocol AccountsAddTableCellViewDelegate: class {
	func addAccount(_ accountType: AccountType)
}

class AccountsAddTableCellView: NSTableCellView {

	weak var delegate: AccountsAddTableCellViewDelegate?
	var accountType: AccountType?
	
	@IBOutlet weak var accountImageView: NSImageView?
	@IBOutlet weak var accountNameLabel: NSTextField?
    
	@IBAction func pressed(_ sender: Any) {
		guard let accountType = accountType else { return }
		delegate?.addAccount(accountType)
	}
	
}
