//
//  SettingsCredentialsAccountView.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 21/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsCredentialsAccountView: View {
	@Environment(\.presentationMode) var presentationMode
	@ObservedObject var settingsModel: SettingsCredentialsAccountModel

	init(account: Account) {
		self.settingsModel = SettingsCredentialsAccountModel(account: account)
	}

	init(accountType: AccountType) {
		self.settingsModel = SettingsCredentialsAccountModel(accountType: accountType)
	}

	var body: some View {
		NavigationView {
			List {
				Section(header: AccountHeaderImageView(image: AppAssets.image(for: settingsModel.accountType)!)) {
					TextField(settingsModel.emailText, text: $settingsModel.email).textContentType(.emailAddress)
					HStack {
						if settingsModel.showPassword {
							TextField("Password", text:$settingsModel.password)
						}
						else {
							SecureField("Password", text: $settingsModel.password)
						}
						Button(action: {
							settingsModel.showPassword.toggle()
						}) {
							Text(settingsModel.showPassword ? "Hide" : "Show")
						}
					}
					if settingsModel.apiUrlEnabled {
						TextField("API URL", text: $settingsModel.apiUrl)
					}
				}
				Section(footer: errorFooter) {
					HStack {
						Spacer()
						Button(action: { settingsModel.addAccount() }) {
							if settingsModel.isUpdate {
								Text("Update Account")
							} else {
								Text("Add Account")
							}
						}
						.disabled(!settingsModel.isValid)
						Spacer()
						if settingsModel.busy {
							ProgressView()
						}
					}
				}
			}
			.listStyle(InsetGroupedListStyle())
			.disabled(settingsModel.busy)
			.onReceive(settingsModel.$shouldDismiss, perform: { dismiss in
				if dismiss == true {
					presentationMode.wrappedValue.dismiss()
				}
			})
			.navigationBarTitle(Text(verbatim: settingsModel.accountName), displayMode: .inline)
			.navigationBarItems(leading:
									Button(action: { self.dismiss() }) { Text("Cancel") }
			)
		}
	}

	var errorFooter: some View {
		HStack {
			Spacer()
			if settingsModel.showError {
				Text(verbatim: settingsModel.accountCredentialsError!.description).foregroundColor(.red)
			}
			Spacer()
		}
	}

	private func dismiss() {
		presentationMode.wrappedValue.dismiss()
	}
}

struct SettingsCredentialsAccountView_Previews: PreviewProvider {
    static var previews: some View {
		SettingsCredentialsAccountView(accountType: .feedbin)
    }
}
