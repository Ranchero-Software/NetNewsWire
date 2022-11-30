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

struct AddAccountWrapper: UIViewControllerRepresentable {
	func makeUIViewController(context: Context) -> AddAccountViewController {
		let controller = UIStoryboard.settings.instantiateViewController(withIdentifier: "AddAccountViewController") as! AddAccountViewController
		return controller
	}
	
	func updateUIViewController(_ uiViewController: AddAccountViewController, context: Context) {
		//
	}
	
	typealias UIViewControllerType = AddAccountViewController
	
}

struct AccountsManagementView: View {
    
	@State private var showAddAccountSheet: Bool = false
	var cancellables = Set<AnyCancellable>()
	@State private var sortedAccounts = [Account]()
	
	var body: some View {
		List {
			ForEach(sortedAccounts, id: \.self) { account in
				accountRow(account)
			}
		}
		.navigationTitle(Text("Accounts"))
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
			NavigationView {
				AddAccountWrapper()
					.navigationTitle("Add Account")
					.navigationBarTitleDisplayMode(.inline)
					.edgesIgnoringSafeArea(.all)
			}
		}
    }
	
	func refreshAccounts() {
		sortedAccounts = []
		sortedAccounts = AccountManager.shared.sortedAccounts
	}
	
	func accountRow(_ account: Account) -> some View {
		NavigationLink {
			AccountInspectorWrapper(account: account)
				.edgesIgnoringSafeArea(.all)
		} label: {
			Image(uiImage: account.smallIcon!.image)
				.resizable()
				.frame(width: 25, height: 25)
			Text(account.nameForDisplay)
		}
	}
	
	var inactiveFooterText: some View {
		if AccountManager.shared.sortedAccounts.filter({ $0.isActive == false }).count == 0 {
			return Text("There are no inactive accounts.")
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
