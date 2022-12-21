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
	@State private var showAccountCredentialsSheet: Bool = false
	var account: Account

	
	var body: some View {
		Form {
			AccountSectionHeader(accountType: account.type)
			accountNameAndActiveSection
			
			if 	account.type != .onMyMac &&
				account.type != .cloudKit &&
				account.type != .feedly {
				credentialsSection
			}
			
			if account != AccountManager.shared.defaultAccount {
				removeAccountSection
			}
			
			if account.type == .cloudKit {
				Section(footer: cloudKitLimitations){}
			}
		}
		.navigationBarTitleDisplayMode(.inline)
		.navigationTitle(account.nameForDisplay)
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
		.edgesIgnoringSafeArea(.bottom)
		.sheet(isPresented: $showAccountCredentialsSheet) {
			switch account.type {
			case .theOldReader, .bazQux, .inoreader, .freshRSS:
				ReaderAPIAddAccountView(accountType: account.type, account: account)
			case .feedbin:
				FeedbinAddAccountView(account: account)
			case .newsBlur:
				NewsBlurAddAccountView(account: account)
			default:
				EmptyView()
			}
		}
		.dismissOnExternalContextLaunch()
    }
	
	var accountHeaderView: some View {
		HStack {
			Spacer()
			Image(uiImage: account.smallIcon!.image)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 48, height: 48)
			Spacer()
		}
	}
	
	var accountNameAndActiveSection: some View {
		Section {
			TextField(text: Binding(
				get: { account.name ?? account.defaultName },
				set: { account.name = $0 }),
					  prompt: Text(account.defaultName)) {
				Text("Name", comment: "Textfield for the user to enter account name.")
			}
			
			Toggle(isOn: Binding(get: {
				account.isActive
			}, set: { account.isActive = $0 })) {
				Text("Active", comment: "Toggle denoting if the account is active.")
			}
		}
	}
	
	var credentialsSection: some View {
		Section {
			Button {
				showAccountCredentialsSheet = true
			} label: {
				HStack {
					Spacer()
					Text("Credentials", comment: "Button title")
					Spacer()
				}
			}
		}
	}
	
	var removeAccountSection: some View {
		Section {
			Button(role: .destructive) {
				showRemoveAccountAlert = true
			} label: {
				HStack {
					Spacer()
					Text("Remove Account", comment: "Button title")
					Spacer()
				}
			}
			.confirmationDialog(Text("Remove Account", comment: "Remove account alert title"), isPresented: $showRemoveAccountAlert, titleVisibility: .visible) {
				Button(role: .destructive) {
					AccountManager.shared.deleteAccount(account)
					dismiss()
				} label: {
					Text("Remove Account", comment: "Button title")
				}
				
				Button(role: .cancel) {
					//
				} label: {
					Text("Cancel", comment: "Button title")
				}

			} message: {
				if account.type == .feedly {
					Text("Are you sure you want to remove this account? NetNewsWire will no longer be able to access articles and feeds unless the account is added again.", comment: "Confirmation of the impacts of deleting the Feedly account.")
				} else {
					Text("Are you sure you want to remove this account? This cannot be undone.", comment: "Confirmation of the impacts of deleting the account.")
				}
			}
		}
	}
	
	var cloudKitLimitations: some View {
		HStack {
			Spacer()
			Text("[iCloud Syncing Limitations & Solutions](https://netnewswire.com/help/iCloud)", comment: "Link to the NetNewsWire iCloud syncing limitations and soltutions website.")
			Spacer()
		}
	}
}

struct AccountInspectorView_Previews: PreviewProvider {
    static var previews: some View {
		AccountInspectorView(account: AccountManager.shared.defaultAccount)
    }
}
