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
	@Environment(\.isPresented) private var isPresented
	@State var name: String

    var body: some View {
		NavigationView {
			Form {
				Section(header:
					SettingsAccountLabelView(accountImage: "accountLocal", accountLabel: Account.defaultLocalAccountName).padding()
				)  {
					HStack {
						Text("Name")
						Divider()
						TextField($name, placeholder: Text("(Optional)"))
					}
				}
				Section {
					HStack {
						Spacer()
						Button(action: { self.addAccount() }) {
							Text("Add Account")
						}
						Spacer()
					}
				}
			}
			.navigationBarTitle(Text(""), displayMode: .inline)
			.navigationBarItems(leading: Button(action: { self.dismiss() }) { Text("Cancel") } )
		}
	}
	
	private func addAccount() {
		let account = AccountManager.shared.createAccount(type: .onMyMac)
		account.name = name
		dismiss()
	}
	
	private func dismiss() {
		isPresented?.value = false
	}
	
}

#if DEBUG
struct SettingsLocalAccountView_Previews : PreviewProvider {
    static var previews: some View {
		SettingsLocalAccountView(name: "")
    }
}
#endif
