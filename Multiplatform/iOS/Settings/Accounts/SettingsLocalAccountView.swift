//
//  SettingsLocalAccountView.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 07/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsLocalAccountView: View {
	@Environment(\.presentationMode) var presentation
	@State var name: String = ""

	var body: some View {
		NavigationView {
			List {
				Section(header: AccountHeaderImageView(image: AppAssets.image(for: .onMyMac)!)) {
					HStack {
						TextField("Name", text: $name)
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
			.listStyle(InsetGroupedListStyle())
			.navigationBarTitle(Text(verbatim: Account.defaultLocalAccountName), displayMode: .inline)
			.navigationBarItems(leading: Button(action: { self.dismiss() }) { Text("Cancel") } )
		}
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

struct SettingsLocalAccountView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsLocalAccountView()
	}
}
