//
//  SettingsLocalAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsLocalAccountView : View {
	@Environment(\.presentationMode) var presentation
	@State var name: String

    var body: some View {
		Form {
			Section(header:
				HStack {
					Spacer()
					SettingsAccountLabelView(accountImage: "accountLocal", accountLabel: Account.defaultLocalAccountName)
						.padding()
						.layoutPriority(1.0)
					Spacer()
				}
			)  {
				HStack {
					TextField("Name", text: $name)
				}
			}
			Section {
				Button(action: { self.addAccount() }) {
					Text("Add Account")
				}
				.buttonStyle(VibrantButtonStyle(alignment: .center))
			}
		}
		.navigationBarTitle(Text(""), displayMode: .inline)
	}
	
	private func addAccount() {
		let account = AccountManager.shared.createAccount(type: .onMyMac)
		account.name = name
		dismiss()
	}
	
	private func dismiss() {
		presentation.wrappedValue.dismiss()
	}
	
}

#if DEBUG
struct SettingsLocalAccountView_Previews : PreviewProvider {
    static var previews: some View {
		SettingsLocalAccountView(name: "")
    }
}
#endif
