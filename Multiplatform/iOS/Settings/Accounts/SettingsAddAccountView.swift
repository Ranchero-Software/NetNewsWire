//
//  SettingsAddAccountView.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 07/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsAddAccountView: View {
	@State private var isAddPresented = false
	@State private var selectedAccountType: AccountType = .onMyMac

	var body: some View {
		List {
			Button(action: {
				self.selectedAccountType = AccountType.onMyMac
				self.isAddPresented = true
			}) {
				SettingsAccountLabelView(
					accountImage: AppAssets.image(for: .onMyMac),
					accountLabel: Account.defaultLocalAccountName
				)
			}
			Button(action: {
				self.selectedAccountType = AccountType.feedbin
				self.isAddPresented = true
			}) {
				SettingsAccountLabelView(
					accountImage: AppAssets.image(for: .feedbin),
					accountLabel: "Feedbin"
				)
			}
		}
		.listStyle(InsetGroupedListStyle())
		.sheet(isPresented: $isAddPresented) {
			if selectedAccountType == .onMyMac {
				SettingsLocalAccountView()
			}
			if selectedAccountType == .feedbin {
				SettingsFeedbinAccountView()
			}
		}
		.navigationBarTitle(Text("Add Account"), displayMode: .inline)
	}
}

struct SettingsAddAccountView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsAddAccountView()
	}
}
