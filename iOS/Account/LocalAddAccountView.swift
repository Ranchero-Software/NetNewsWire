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
					Button(action: { dismiss() }, label: { Text("Cancel", comment: "Button title") })
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
				  prompt: Text("Name", comment: "Textfield placeholder for the name of the account."))
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
				Text("Add Account", comment: "Button title")
				Spacer()
			}
		}
	}
	
	var accountFooterView: some View {
		HStack {
			Spacer()
			Text("Local accounts do not sync your feeds across devices.", comment: "Explanatory text describing the local account.")
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
			return Text("On My iPad", comment: "Account name for iPad")
		}
		return Text("On My iPhone", comment: "Account name for iPhone")
	}
}

struct LocalAddAccountView_Previews: PreviewProvider {
    static var previews: some View {
        LocalAddAccountView()
    }
}
