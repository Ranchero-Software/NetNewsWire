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
	@State private var selectedAccountType: AccountType = nil
	
    var body: some View {
		Form {
			
			Button(action: {
				self.selectedAccountType = AccountType.onMyMac
			}) {
				SettingsAccountLabelView(accountImage: "accountLocal", accountLabel: Account.defaultLocalAccountName)
			}
			
			Button(action: {
				self.selectedAccountType = AccountType.feedbin
			}) {
				SettingsAccountLabelView(accountImage: "accountFeedbin", accountLabel: "Feedbin")
			}

			
		}
		.sheet(item: $selectedAccountType) { accountType in
			if accountType == .onMyMac {
				SettingsLocalAccountView(name: "", onDismiss: { self.presentation.wrappedValue.dismiss() })
			}
			if accountType == .feedbin {
				SettingsFeedbinAccountView(viewModel: SettingsFeedbinAccountView.ViewModel(), onDismiss: { self.presentation.wrappedValue.dismiss() })
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
