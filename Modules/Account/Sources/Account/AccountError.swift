//
//  AccountError.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import Web
import CommonErrors

public extension AccountError {

	@MainActor var account: Account? {
		if case .wrappedError(_, let accountID, _) = self {
			return AccountManager.shared.existingAccount(with: accountID)
		} else {
			return nil
		}
	}

	@MainActor static func wrappedError(error: Error, account: Account) -> AccountError {
		wrappedError(error: error, accountID: account.accountID, accountName: account.nameForDisplay)
	}
}
