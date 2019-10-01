//
//  SettingsAddAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsAddAccountView : View {
	@Environment(\.presentationMode) var presentation
	@State private var accountAddAction: Int? = nil

    var body: some View {
		Form {
			
			NavigationLink(destination: SettingsLocalAccountView(name: ""), tag: 1, selection: $accountAddAction) {
				SettingsAccountLabelView(accountImage: "accountLocal", accountLabel: Account.defaultLocalAccountName)
			}
			.modifier(VibrantSelectAction(action: {
				self.accountAddAction = 1
			})).padding(.vertical, 16)
			
			NavigationLink(destination: SettingsFeedbinAccountView(viewModel: SettingsFeedbinAccountView.ViewModel()), tag: 2, selection: $accountAddAction) {
				SettingsAccountLabelView(accountImage: "accountFeedbin", accountLabel: "Feedbin")

			}
			.modifier(VibrantSelectAction(action: {
				self.accountAddAction = 2
			})).padding(.vertical, 16)

//			NavigationLink(destination: SettingsReaderAPIAccountView(viewModel: SettingsReaderAPIAccountView.ViewModel(accountType: .freshRSS)), tag: 3, selection: $accountAddAction) {
//				SettingsAccountLabelView(accountImage: "accountFreshRSS", accountLabel: "Fresh RSS")
//			}
//			.modifier(VibrantSelectAction(action: {
//				self.accountAddAction = 3
//			}))
			
		}
		.navigationBarTitle(Text("Add Account"), displayMode: .inline)
	}
}

#if DEBUG
struct AddAccountView_Previews : PreviewProvider {
    static var previews: some View {
        SettingsAddAccountView()
    }
}
#endif
