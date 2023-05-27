//
//  LocalAddAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 18/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct LocalAddAccountView: View {
    
	@Environment(\.dismiss) var dismiss
	@State private var accountName: String = ""
	
	var body: some View {
		NavigationView {
			Form {
				AccountSectionHeader(accountType: .onMyMac)
				Section { accountNameSection }
				Section { addAccountButton }
				Section(footer: accountFooterView) {}
			}
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button(action: { dismiss() }, label: { Text("button.title.cancel", comment: "Cancel") })
				}
			}
			.navigationTitle(deviceAccountName())
			.navigationBarTitleDisplayMode(.inline)
			.dismissOnExternalContextLaunch()
			.dismissOnAccountAdd()
		}
    }
	
	var accountNameSection: some View {
		TextField("Name",
				  text: $accountName,
				  prompt: Text("textfield.placeholder.name", comment: "Name"))
		.autocorrectionDisabled()
		.autocapitalization(.none)
	}
	
	var addAccountButton: some View {
		Button {
			let account = AccountManager.shared.createAccount(type: .onMyMac)
			if accountName.trimmingWhitespace.count > 0 { account.name = accountName }
		} label: {
			HStack {
				Spacer()
				Text("button.title.add-account", comment: "Add Account")
				Spacer()
			}
		}
	}
	
	var accountFooterView: some View {
		HStack {
			Spacer()
			Text("label.text.local-account-explainer", comment: "Local accounts do not sync your feeds across devices")
				.multilineTextAlignment(.center)
			Spacer()
		}
	}
	
	private func accountImage() -> UIImage {
		if UIDevice.current.userInterfaceIdiom == .pad {
			return AppAssets.accountLocalPadImage
		}
		return AppAssets.accountLocalPhoneImage
	}
	
	private func deviceAccountName() -> Text {
		Text(verbatim: AccountType.onMyMac.localizedAccountName())
	}
}

struct LocalAddAccountView_Previews: PreviewProvider {
    static var previews: some View {
        LocalAddAccountView()
    }
}
