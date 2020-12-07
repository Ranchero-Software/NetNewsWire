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
	@StateObject private var model = SettingsAddAccountModel()

	var body: some View {
		List {
			ForEach(model.accounts) { account in
				Button(action: {
					model.selectedAccountType = account.accountType
				}) {
					SettingsAccountLabelView(
						accountImage: account.image,
						accountLabel: account.name
					)
				}
			}
		}
		.listStyle(InsetGroupedListStyle())
		.sheet(isPresented: $model.isAddPresented) {
			switch model.selectedAccountType! {
			case .onMyMac:
				AddLocalAccountView()
			case .feedbin:
				AddFeedbinAccountView()
			case .cloudKit:
				AddCloudKitAccountView()
			case .feedWrangler:
				AddFeedWranglerAccountView()
			case .newsBlur:
				AddNewsBlurAccountView()
			case .feedly:
				AddFeedlyAccountView()
			default:
				AddReaderAPIAccountView(accountType: model.selectedAccountType!)
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
