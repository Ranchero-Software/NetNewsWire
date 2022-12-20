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
					Button(action: { dismiss() }, label: { Text("CANCEL_BUTTON_TITLE", tableName: "Buttons") })
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
				  prompt: Text("ACCOUNT_NAME", tableName: "Account"))
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
				Text("ADD_ACCOUNT_BUTTON_TITLE", tableName: "Buttons")
				Spacer()
			}
		}
	}
	
	var accountFooterView: some View {
		HStack {
			Spacer()
			Text("LOCAL_FOOTER_EXPLAINER", tableName: "Account")
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
		if UIDevice.current.userInterfaceIdiom == .pad {
			return Text("LOCAL_ACCOUNT_NAME_PAD", tableName: "Account")
		}
		return Text("LOCAL_ACCOUNT_NAME_PHONE", tableName: "Account")
	}
}

struct LocalAddAccountView_Previews: PreviewProvider {
    static var previews: some View {
        LocalAddAccountView()
    }
}
