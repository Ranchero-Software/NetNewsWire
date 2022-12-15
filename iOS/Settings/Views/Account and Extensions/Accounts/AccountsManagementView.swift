//
//  AccountsManagementView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 13/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import Combine

struct AccountsManagementView: View {
    
	@State private var showAddAccountSheet: Bool = false
	@State private var sortedActiveAccounts = [Account]()
	@State private var sortedInactiveAccounts = [Account]()
	@State private var accountToRemove: Account?
	@State private var showRemoveAccountAlert: Bool = false
	
	var body: some View {
		List {
			Section(header: Text("ACTIVE_ACCOUNTS_HEADER", tableName: "Settings")) {
				ForEach(sortedActiveAccounts, id: \.self) { account in
					accountRow(account, showRemoveAccountAlert: $showRemoveAccountAlert, accountToRemove: $accountToRemove)
				}
			}
			
			Section(header: Text("INACTIVE_ACCOUNTS_HEADER", tableName: "Settings")) {
				ForEach(sortedInactiveAccounts, id: \.self) { account in
					accountRow(account, showRemoveAccountAlert: $showRemoveAccountAlert, accountToRemove: $accountToRemove)
				}
			}
			
		}
		.navigationTitle(Text("MANAGE_ACCOUNTS", tableName: "Settings"))
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					showAddAccountSheet = true
				} label: {
					Image(systemName: "plus")
				}
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .AccountStateDidChange)) { _ in
			refreshAccounts()
		}
		.onReceive(NotificationCenter.default.publisher(for: .UserDidAddAccount)) { _ in
			refreshAccounts()
		}
		.onReceive(NotificationCenter.default.publisher(for: .UserDidDeleteAccount)) { _ in
			refreshAccounts()
		}
		.onReceive(NotificationCenter.default.publisher(for: .DisplayNameDidChange)) { _ in
			refreshAccounts()
		}
		.task(priority: .userInitiated) {
			refreshAccounts()
		}
		.sheet(isPresented: $showAddAccountSheet) {
			AddAccountView()
		}
		.alert(Text("ACCOUNT_REMOVE \(accountToRemove?.nameForDisplay ?? "")", tableName: "Settings"),
			   isPresented: $showRemoveAccountAlert) {
			Button(role: .destructive) {
				AccountManager.shared.deleteAccount(accountToRemove!)
			} label: {
				Text("REMOVE", tableName: "Settings")
			}
			
			Button(role: .cancel) {
				accountToRemove = nil
			} label: {
				Text("CANCEL", tableName: "Settings")
			}
		} message: {
			switch accountToRemove {
			case .none:
			    Text("")
			case .some(let wrapped):
				switch wrapped.type {
				case .feedly:
					Text("REMOVE_FEEDLY_CONFIRMATION", tableName: "Settings")
				default:
					Text("REMOVE_ACCOUNT_CONFIRMATION", tableName: "Settings")
				}
			}
		}
    }
	
	func refreshAccounts() {
		sortedActiveAccounts = AccountManager.shared.sortedActiveAccounts
		sortedInactiveAccounts = AccountManager.shared.sortedAccounts.filter({ $0.isActive == false })
	}
	
	func accountRow(_ account: Account, showRemoveAccountAlert: Binding<Bool>, accountToRemove: Binding<Account?>) -> some View {
		NavigationLink {
			AccountInspectorWrapper(account: account)
				.edgesIgnoringSafeArea(.all)
		} label: {
			Image(uiImage: account.smallIcon!.image)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 25, height: 25)
			Text(account.nameForDisplay)
		}.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			if account != AccountManager.shared.defaultAccount {
				Button(role: .destructive) {
					accountToRemove.wrappedValue = account
					showRemoveAccountAlert.wrappedValue = true
				} label: {
					Label {
						Text("REMOVE_ACCOUNT", tableName: "Settings")
					} icon: {
						Image(systemName: "trash")
					}
				}.tint(.red)
			}
		}
	}
	
	var inactiveFooterText: some View {
		if AccountManager.shared.sortedAccounts.filter({ $0.isActive == false }).count == 0 {
			return Text("NO_INACTIVE_ACCOUNT_FOOTER", tableName: "Settings")
		} else {
			return Text("")
		}
	}
	
}

struct AddAccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountsManagementView()
    }
}
