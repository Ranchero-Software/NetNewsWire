//
//  SettingsDetailAccountView.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 08/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Combine
import Account
import RSWeb
import RSCore

struct SettingsDetailAccountView: View {
	@Environment(\.presentationMode) var presentationMode
	@ObservedObject var settingsModel: SettingsDetailAccountModel
	@State private var isFeedbinCredentialsPresented = false
	@State private var isDeleteAlertPresented = false

	init(_ account: Account) {
		settingsModel = SettingsDetailAccountModel.init(account)
	}

	var body: some View {
		List {
			Section(header:AccountHeaderImageView(image: settingsModel.accountImage)) {
				HStack {
					TextField(settingsModel.defaultName, text: $settingsModel.name)
				}
				Toggle(isOn: $settingsModel.isActive) {
					Text("Active")
				}
			}
			if settingsModel.isCredentialsAvailable {
				Section {
					HStack {
						Spacer()
						Button(action: {
							self.isFeedbinCredentialsPresented.toggle()
						}) {
							Text("Credentials")
						}
						Spacer()
					}
				}
				.sheet(isPresented: $isFeedbinCredentialsPresented) {
					self.settingsCredentialsAccountView
				}
			}
			if settingsModel.isDeletable {
				Section {
					HStack {
						Spacer()
						Button(action: {
							self.isDeleteAlertPresented.toggle()
						}) {
							Text("Delete Account").foregroundColor(.red)
						}
						Spacer()
					}
					.alert(isPresented: $isDeleteAlertPresented) {
						Alert(
							title: Text("Are you sure you want to delete \"\(settingsModel.nameForDisplay)\"?"),
							primaryButton: Alert.Button.default(
								Text("Delete"),
								action: {
									self.settingsModel.delete()
									self.dismiss()
								}),
							secondaryButton: Alert.Button.cancel()
						)
					}
				}
			}
		}
		.listStyle(InsetGroupedListStyle())
		.navigationBarTitle(Text(verbatim: settingsModel.nameForDisplay), displayMode: .inline)
	}

	var settingsCredentialsAccountView: SettingsCredentialsAccountView {
		return SettingsCredentialsAccountView(account: settingsModel.account)
	}

	func dismiss() {
		presentationMode.wrappedValue.dismiss()
	}
}

struct SettingsDetailAccountView_Previews: PreviewProvider {
	static var previews: some View {
		return SettingsDetailAccountView(AccountManager.shared.defaultAccount)
	}
}
