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
			Section(header: accountHeaderView){}
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
				Text("FEEDBIN")
			case .newsBlur:
				Text("NEWSBLUR")
			default:
				EmptyView()
			}
		}
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
				Text("ACCOUNT_NAME", tableName: "Inspector")
			}
			
			Toggle(isOn: Binding(get: {
				account.isActive
			}, set: { account.isActive = $0 })) {
				Text("ACTIVE", tableName: "Inspector")
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
					Text("CREDENTIALS_BUTTON_TITLE", tableName: "Buttons")
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
					Text("REMOVE_ACCOUNT_BUTTON_TITLE", tableName: "Buttons")
					Spacer()
				}
			}
			.confirmationDialog(Text("REMOVE_ACCOUNT_TITLE", tableName: "Inspector"), isPresented: $showRemoveAccountAlert, titleVisibility: .visible) {
				Button(role: .destructive) {
					AccountManager.shared.deleteAccount(account)
					dismiss()
				} label: {
					Text("REMOVE_ACCOUNT_BUTTON_TITLE", tableName: "Buttons")
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
