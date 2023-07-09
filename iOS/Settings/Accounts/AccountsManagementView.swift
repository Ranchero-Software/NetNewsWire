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

@MainActor public final class AccountManagementViewModel: ObservableObject {
	
	@Published var sortedActiveAccounts = [Account]()
	@Published var sortedInactiveAccounts = [Account]()
	@Published var accountsForDeletion = [Account]()
	@Published var showAccountDeletionAlert: Bool = false
	@Published var showAddAccountSheet: Bool = false
	public var accountToDelete: Account? = nil
	
	init() {
		refreshAccounts()
		
		NotificationCenter.default.addObserver(self, selector: #selector(refreshAccounts(_:)), name: .AccountStateDidChange, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(refreshAccounts(_:)), name: .UserDidAddAccount, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(refreshAccounts(_:)), name: .UserDidDeleteAccount, object: nil)
		
		NotificationCenter.default.addObserver(self, selector: #selector(refreshAccounts(_:)), name: .DisplayNameDidChange, object: nil)
	}
	
	func temporarilyDeleteAccount(_ account: Account) {
		if account.isActive {
			sortedActiveAccounts.removeAll(where: { $0.accountID == account.accountID })
		} else {
			sortedInactiveAccounts.removeAll(where: { $0.accountID == account.accountID })
		}
		accountToDelete = account
		showAccountDeletionAlert = true
	}
	
	func restoreAccount(_ account: Account) {
		accountToDelete = nil
		self.refreshAccounts()
	}
	
	@objc
	private func refreshAccounts(_ sender: Any? = nil) {
		sortedActiveAccounts = AccountManager.shared.sortedActiveAccounts
		sortedInactiveAccounts = AccountManager.shared.sortedAccounts.filter({ $0.isActive == false })
	}
		
}


struct AccountsManagementView: View {
    
	@StateObject private var viewModel = AccountManagementViewModel()
	
	var body: some View {
		List {
			Section(header: Text("label.text.active-accounts", comment: "Active Accounts")) {
				ForEach(viewModel.sortedActiveAccounts, id: \.self) { account in
					accountRow(account)
				}
			}
			
			Section(header: Text("label.text.inactive-accounts", comment: "Inactive Accounts")) {
				ForEach(viewModel.sortedInactiveAccounts, id: \.self) { account in
					accountRow(account)
				}
			}
		}
		.navigationTitle(Text("navigation.title.manage-accounts", comment: "Manage Accounts"))
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					viewModel.showAddAccountSheet = true
				} label: {
					Image(systemName: "plus")
				}
			}
		}
		.sheet(isPresented: $viewModel.showAddAccountSheet) {
			AddAccountListView()
		}
		.alert(Text("alert.title.remove-account.\(viewModel.accountToDelete?.nameForDisplay ?? "")", comment: "Are you sure you want to remove “%@“?"),
			   isPresented: $viewModel.showAccountDeletionAlert) {
			Button(role: .destructive) {
				AccountManager.shared.deleteAccount(viewModel.accountToDelete!)
			} label: {
				Text("button.title.remove-account", comment: "Remove Account")
			}
			
			Button(role: .cancel) {
				viewModel.restoreAccount(viewModel.accountToDelete!)
			} label: {
				Text("button.title.cancel", comment: "Cancel")
			}
		} message: {
			Text("alert.message.cannot-undo-action", comment: "The action cannot be undone.")
		}
    }
	
	func accountRow(_ account: Account) -> some View {
		NavigationLink {
			AccountInspectorView(account: account)
		} label: {
			Image(uiImage: account.smallIcon!.image)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(width: 25, height: 25)
			Text(verbatim: account.nameForDisplay)
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			if account != AccountManager.shared.defaultAccount {
				Button(role: .destructive) {
					viewModel.temporarilyDeleteAccount(account)
				} label: {
					Label {
						Text("button.title.remove-account", comment: "Remove Account")
					} icon: {
						Image(systemName: "trash")
					}
				}
			}
			Button {
				account.isActive.toggle()
			} label: {
				Label {
					if account.isActive {
						Text("button.title.deactivate-account", comment: "Deactivate Account")
					} else {
						Text("button.title.activate-account", comment: "Activate Account")
					}
				} icon: {
					if account.isActive {
						Image(systemName: "minus.circle")
					} else {
						Image(systemName: "togglepower")
					}
				}
			}.tint(account.isActive ? .yellow : Color(uiColor: AppAssets.primaryAccentColor))
		}
	}
}

struct AddAccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountsManagementView()
    }
}
