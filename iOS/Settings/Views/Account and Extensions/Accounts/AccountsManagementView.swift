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

public final class AccountManagementViewModel: ObservableObject {
	
	@Published var sortedActiveAccounts = [Account]()
	@Published var sortedInactiveAccounts = [Account]()
	@Published var showAccountDeletionAlert: Bool = false
	@Published var showAddAccountSheet: Bool = false
	public var accountToDelete: Account? = nil
	
	init() {
		refreshAccounts()
		
		NotificationCenter.default.addObserver(forName: .AccountStateDidChange, object: nil, queue: .main) { [weak self] _ in
			self?.refreshAccounts()
		}
		
		NotificationCenter.default.addObserver(forName: .UserDidAddAccount, object: nil, queue: .main) { [weak self] _ in
			self?.refreshAccounts()
		}
		
		NotificationCenter.default.addObserver(forName: .UserDidDeleteAccount, object: nil, queue: .main) { [weak self] _ in
			self?.refreshAccounts()
		}
		
		NotificationCenter.default.addObserver(forName: .DisplayNameDidChange, object: nil, queue: .main) { [weak self] _ in
			self?.refreshAccounts()
		}
	}
	
	private func refreshAccounts() {
		sortedActiveAccounts = AccountManager.shared.sortedActiveAccounts
		sortedInactiveAccounts = AccountManager.shared.sortedAccounts.filter({ $0.isActive == false })
	}
	
}


struct AccountsManagementView: View {
    
	@StateObject private var viewModel = AccountManagementViewModel()
	
	var body: some View {
		List {
			Section(header: Text("ACTIVE_ACCOUNTS_HEADER", tableName: "Settings")) {
				ForEach(viewModel.sortedActiveAccounts, id: \.self) { account in
					accountRow(account)
				}
			}
			
			Section(header: Text("INACTIVE_ACCOUNTS_HEADER", tableName: "Settings")) {
				ForEach(viewModel.sortedInactiveAccounts, id: \.self) { account in
					accountRow(account)
				}
			}
		}
		.navigationTitle(Text("MANAGE_ACCOUNTS", tableName: "Settings"))
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
		.alert(Text("ACCOUNT_REMOVE \(viewModel.accountToDelete?.nameForDisplay ?? "")", tableName: "Settings"),
			   isPresented: $viewModel.showAccountDeletionAlert) {
			Button(role: .destructive) {
				AccountManager.shared.deleteAccount(viewModel.accountToDelete!)
			} label: {
				Text("REMOVE_ACCOUNT_BUTTON_TITLE", tableName: "Buttons")
			}
			
			Button(role: .cancel) {
				//
			} label: {
				Text("CANCEL_BUTTON_TITLE", tableName: "Buttons")
			}
		} message: {
			switch viewModel.accountToDelete {
			case .none:
			    Text("")
			case .some(let account):
				switch account.type {
				case .feedly:
					Text("REMOVE_FEEDLY_CONFIRMATION", tableName: "Settings")
				default:
					Text("REMOVE_ACCOUNT_CONFIRMATION", tableName: "Settings")
				}
			}
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
			Text(account.nameForDisplay)
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			if account != AccountManager.shared.defaultAccount {
				Button(role: .destructive) {
					viewModel.accountToDelete = account
					viewModel.showAccountDeletionAlert = true
				} label: {
					Label {
						Text("REMOVE_ACCOUNT_BUTTON_TITLE", tableName: "Buttons")
					} icon: {
						Image(systemName: "trash")
					}
				}
			}
			Button {
				withAnimation {
					account.isActive.toggle()
				}
			} label: {
				if account.isActive {
					Image(systemName: "minus.circle")
				} else {
					Image(systemName: "togglepower")
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
