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
	
    var body: some View {
		Form {
			NavigationLink(destination: SettingsLocalAccountView(name: "")) {
				SettingsAccountLabelView(accountImage: "accountLocal", accountLabel: Account.defaultLocalAccountName)
			}
			NavigationLink(destination: SettingsFeedbinAccountView(viewModel: SettingsFeedbinAccountView.ViewModel())) {
				SettingsAccountLabelView(accountImage: "accountFeedbin", accountLabel: "Feedbin")
			}
			NavigationLink(destination: SettingsReaderAPIAccountView(viewModel: SettingsReaderAPIAccountView.ViewModel(accountType: .freshRSS))) {
				SettingsAccountLabelView(accountImage: "accountFreshRSS", accountLabel: "Fresh RSS")
			}
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
