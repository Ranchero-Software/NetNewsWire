//
//  AccountInspectorView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 15/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import SafariServices
import Account

struct AccountInspectorView: View {
    
	@Environment(\.dismiss) var dismiss
	@State private var showRemoveAccountAlert: Bool = false
	var account: Account
	
	var body: some View {
		Form {
			Section(header: accountHeaderView){}
	
			TextField(text: Binding(
				get: { account.name ?? account.defaultName },
				set: { account.name = $0 }),
					  prompt: Text(account.defaultName)) {
				Text("ACCOUNT_NAME", tableName: "Inspector")
			}
			
			Toggle(isOn: Binding(get: {
				account.isActive
			}, set: { account.isActive = $0 })) {
				Text("ACTIVE", tableName: "Inspector")
			}
			
			if account != AccountManager.shared.defaultAccount {
				Section {
					Button(role: .destructive) {
						showRemoveAccountAlert = true
					} label: {
						HStack {
							Spacer()
							Text("REMOVE_ACCOUNT_BUTTON_TITLE", tableName: "Inspector")
							Spacer()
						}
					}
					.confirmationDialog(Text("REMOVE_ACCOUNT_TITLE", tableName: "Inspector"), isPresented: $showRemoveAccountAlert, titleVisibility: .visible) {
						Button(role: .destructive) {
							AccountManager.shared.deleteAccount(account)
							dismiss()
						} label: {
							Text("REMOVE_ACCOUNT_BUTTON_TITLE", tableName: "Inspector")
						}
						
						Button(role: .cancel) {
							//
						} label: {
							Text("CANCEL_BUTTON_TITLE", tableName: "Buttons")
						}

					} message: {
						if account.type == .feedly {
							Text("REMOVE_FEEDLY_MESSAGE", tableName: "Inspector")
						} else {
							Text("REMOVE_ACCOUNT_MESSAGE", tableName: "Inspector")
						}
					}
				}
			}
			
			if account.type == .cloudKit {
				Section(footer: cloudKitLimitations){}
			}
		}
		.navigationBarTitleDisplayMode(.inline)
		.navigationTitle(account.nameForDisplay)
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
		.edgesIgnoringSafeArea(.bottom) // Fix to make sure view is not offset from the top when presented
    }
	
	var accountHeaderView: some View {
		HStack {
			Spacer()
			Image(uiImage: account.smallIcon!.image)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 30, height: 30)
			Spacer()
		}
	}
	
	var cloudKitLimitations: some View {
		HStack {
			Spacer()
			Text("CLOUDKIT_LIMITATIONS_TITLE", tableName: "Inspector")
			Spacer()
		}
	}
}

struct AccountInspectorView_Previews: PreviewProvider {
    static var previews: some View {
		AccountInspectorView(account: AccountManager.shared.defaultAccount)
    }
}
