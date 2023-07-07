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
					  prompt: Text(verbatim: account.defaultName)) {
				Text("textfield.placeholder.name", comment: "Name")
			}
			
			Toggle(isOn: Binding(get: {
				account.isActive
			}, set: { account.isActive = $0 })) {
				Text("toggle.account.active", comment: "Active")
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
					Text("button.title.credentials", comment: "Credentials")
					Spacer()
				}
			}
		}
	}
	
	@MainActor var removeAccountSection: some View {
		Section {
			Button(role: .destructive) {
				showRemoveAccountAlert = true
			} label: {
				HStack {
					Spacer()
					Text("button.title.remove-account", comment: "Remove Account")
					Spacer()
				}
			}
			.alert(Text("alert.title.remove-account.\(account.nameForDisplay)", comment: "Are you sure you want to remove “%@“?"), isPresented: $showRemoveAccountAlert) {
				Button(role: .destructive) {
					AccountManager.shared.deleteAccount(account)
					dismiss()
				} label: {
					Text("button.title.remove-account", comment: "Remove Account")
				}
				
				Button(role: .cancel) {
					//
				} label: {
					Text("button.title.cancel", comment: "Cancel")
				}

			} message: {
				Text("alert.message.cannot-undo-action", comment: "You can't undo this action.")
			}
		}
	}
	
	var cloudKitLimitations: some View {
		HStack {
			Spacer()
			Text("link.markdown.icloud-limitations", comment: "Link to the NetNewsWire iCloud syncing limitations and soltutions website.")
			Spacer()
		}
	}
}

struct AccountInspectorView_Previews: PreviewProvider {
    static var previews: some View {
		AccountInspectorView(account: AccountManager.shared.defaultAccount)
    }
}
