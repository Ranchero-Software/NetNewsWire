//
//  Account+CredentialsView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/25/26.
//

import SwiftUI
import Account

extension Account {

	var hasCredentialsView: Bool {
		type == .miniflux || CredentialsAccountView.accountTypes.contains(type)
	}

	/// The view for updating this account’s credentials.
	@ViewBuilder func credentialsView() -> some View {
		if type == .miniflux {
			MinifluxAccountView(account: self, didAddAccount: nil)
		} else {
			CredentialsAccountView(accountType: type, account: self, didAddAccount: nil)
		}
	}
}
