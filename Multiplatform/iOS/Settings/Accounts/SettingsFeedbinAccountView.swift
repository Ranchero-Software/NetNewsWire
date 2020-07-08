//
//  SettingsFeedbinAccountView.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 07/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import Combine
import RSWeb
import Secrets

struct SettingsFeedbinAccountView: View {
	@Environment(\.presentationMode) var presentationMode
	@StateObject var settingsModel = SettingsFeedbinAccountModel()

	var body: some View {
		NavigationView {
			List {
				Section {
					imageView
					TextField("Email", text: $settingsModel.email).textContentType(.emailAddress)
					SecureField("Password", text: $settingsModel.password)
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
			.onReceive(settingsModel.$shouldDismiss, perform: { dismiss in
				if dismiss == true {
					presentationMode.wrappedValue.dismiss()
				}
			})
			.listStyle(InsetGroupedListStyle())
			.disabled(settingsModel.busy)
			.navigationBarTitle(Text(verbatim: "Feedbin"), displayMode: .inline)
			.navigationBarItems(leading:
									Button(action: { self.dismiss() }) { Text("Cancel") }
			)
		}
	}

	var imageView: some View {
		HStack {
			Spacer()
			Image(rsImage: AppAssets.image(for: .feedbin)!)
				.resizable()
				.aspectRatio(1, contentMode: .fit)
				.frame(height: 48, alignment: .center)
				.padding()
			Spacer()
		}
		.listRowBackground(Color.clear)
	}

	var errorFooter: some View {
		HStack {
			Spacer()
			if settingsModel.showError {
				Text(verbatim: settingsModel.feedbinAccountError!.localizedDescription).foregroundColor(.red)
			}
			Spacer()
		}
	}

	private func dismiss() {
		presentationMode.wrappedValue.dismiss()
	}
}

struct SettingsFeedbinAccountView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsFeedbinAccountView()
	}
}
