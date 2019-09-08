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
	
	@State private var isAddPresented = false
	@State private var selectedAccountType: AccountType = nil
	
    var body: some View {
		Form {
			
			Button(action: {
				self.selectedAccountType = AccountType.onMyMac
				self.isAddPresented.toggle()
			}) {
				SettingsAccountLabelView(accountImage: "accountLocal", accountLabel: Account.defaultLocalAccountName)
			}
			
			Button(action: {
				self.selectedAccountType = AccountType.feedbin
				self.isAddPresented.toggle()
			}) {
				SettingsAccountLabelView(accountImage: "accountFeedbin", accountLabel: "Feedbin")
			}

			
		}
		.sheet(isPresented: $isAddPresented) {
			if self.selectedAccountType == .onMyMac {
				SettingsLocalAccountView(name: "")
			}
			if self.selectedAccountType == .feedbin {
				SettingsFeedbinAccountView(viewModel: SettingsFeedbinAccountView.ViewModel())
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
