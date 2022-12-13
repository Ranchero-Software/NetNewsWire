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
		
		
		context.coordinator.parentObserver = controller.observe(\.parent, changeHandler: { vc, _ in
			vc.parent?.title = vc.title
			vc.parent?.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction(title: NSLocalizedString("Done", comment: "Done"), image: nil, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off, handler: { _ in
				controller.dismiss(animated: true	)
			}), menu: nil)
		})
		
		return controller
	}
	
	func updateUIViewController(_ uiViewController: AddAccountViewController, context: Context) {
		//
	}
	
	class Coordinator {
		var parentObserver: NSKeyValueObservation?
	}
	
	func makeCoordinator() -> Self.Coordinator { Coordinator() }
	
	typealias UIViewControllerType = AddAccountViewController
	
}

struct AccountsManagementView: View {
    
	@State private var showAddAccountSheet: Bool = false
	var cancellables = Set<AnyCancellable>()
	@State private var sortedAccounts = [Account]()
	@State private var accountToRemove: Account?
	@State private var showRemoveAccountAlert: Bool = false
	
	var body: some View {
		List {
			ForEach(sortedAccounts, id: \.self) { account in
				accountRow(account, showRemoveAccountAlert: $showRemoveAccountAlert, accountToRemove: $accountToRemove)
			}
		}
		.navigationTitle(Text("Manage Accounts"))
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
			AddAccountListView()
		}
		.alert("Remove “\(accountToRemove?.nameForDisplay ?? "")”?",
			   isPresented: $showRemoveAccountAlert) {
			Button(role: .destructive) {
				AccountManager.shared.deleteAccount(accountToRemove!)
			} label: {
				Text("Remove")
			}
			
			Button(role: .cancel) {
				accountToRemove = nil
			} label: {
				Text("Cancel")
			}
		} message: {
			switch accountToRemove {
			case .none:
			    Text("")
			case .some(let wrapped):
				switch wrapped.type {
				case .feedly:
					Text("Are you sure you want to remove this account? NetNewsWire will no longer be able to access articles and feeds unless the account is added again.")
				default:
					Text("Are you sure you want to remove this account? This cannot be undone.")
				}
			}
		}

    }
	
	func refreshAccounts() {
		sortedAccounts = []
		sortedAccounts = AccountManager.shared.sortedAccounts
	}
	
	func accountRow(_ account: Account, showRemoveAccountAlert: Binding<Bool>, accountToRemove: Binding<Account?>) -> some View {
		NavigationLink {
			AccountInspectorWrapper(account: account)
				.edgesIgnoringSafeArea(.all)
		} label: {
			Image(uiImage: account.smallIcon!.image)
				.resizable()
				.frame(width: 25, height: 25)
			Text(account.nameForDisplay)
		}.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			if account != AccountManager.shared.defaultAccount {
				Button(role: .destructive) {
					accountToRemove.wrappedValue = account
					showRemoveAccountAlert.wrappedValue = true
				} label: {
					Label("Remove Account", systemImage: "trash")
				}.tint(.red)
			}
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
