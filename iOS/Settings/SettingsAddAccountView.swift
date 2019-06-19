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
    var body: some View {
		Form {
			PresentationButton(destination: SettingsLocalAccountView(name: "")) {
				SettingsAccountLabelView(accountImage: "accountLocal", accountLabel: Account.defaultLocalAccountName)
			}
			.padding(4)
			PresentationButton(destination: SettingsFeedbinAccountView(viewModel: SettingsFeedbinAccountView.ViewModel())) {
				SettingsAccountLabelView(accountImage: "accountFeedbin", accountLabel: "Feedbin")
			}
			.padding(4)
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
