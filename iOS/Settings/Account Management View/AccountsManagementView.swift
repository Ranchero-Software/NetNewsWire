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
	var cancellables = Set<AnyCancellable>()
	@State private var updated: Bool = false
	
	
	var body: some View {
		List {
			ForEach(AccountManager.shared.sortedActiveAccounts, id: \.accountID) { account in
				Section(footer: accountFooterText(account)) {
					accountRow(account)
				}
			}
			
			Section(header: Text("Inactive Accounts"), footer: inactiveFooterText) {
				ForEach(0..<AccountManager.shared.sortedAccounts.filter({ $0.isActive == false }).count, id: \.self) { i in
					accountRow(AccountManager.shared.sortedAccounts.filter({ $0.isActive == false })[i])
				}
			}
		}
		.navigationTitle(Text("Accounts"))
		.navigationBarTitleDisplayMode(.inline)
		.tint(Color(uiColor: AppAssets.primaryAccentColor))
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					//
				} label: {
					Image(systemName: "plus")
				}
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .AccountStateDidChange)) { _ in
			updated.toggle()
		}
    }
	
	var addAccountButton: some View {
		HStack {
			Spacer()
			Text("Add Account")
				.padding(8)
				.overlay(NavigationLink { AddAccountViewControllerRepresentable() } label: { EmptyView() }.opacity(0.0))
				.background(Color(uiColor: AppAssets.primaryAccentColor))
				.clipShape(RoundedRectangle(cornerRadius: 6))
			Spacer()
		}
	}
	
	func accountFooterText(_ account: Account) -> some View {
		if account.type == .cloudKit {
			return Text("iCloud Syncing Limitations & Solutions")
		} else {
			return Text("")
		}
	}
	
	func accountRow(_ account: Account) -> some View {
		Group {
			HStack {
				Image(uiImage: account.smallIcon!.image)
					.resizable()
					.frame(width: 25, height: 25)
				TextField(text: Binding(get: { account.nameForDisplay }, set: { account.name = $0 })) {
					Text(account.nameForDisplay)
				}.foregroundColor(.secondary)
			}
			Toggle(isOn: Binding<Bool>(
				get: { account.isActive },
				set: { account.isActive = $0 }
			)) {
				Text("Active")
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
