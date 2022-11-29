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
	@State private var sortedAccounts = [Account]()
	
	var body: some View {
		List {
			ForEach(sortedAccounts, id: \.self) { account in
				Section(header: Text("")) {
					accountRow(account)
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
			sortedAccounts = AccountManager.shared.sortedAccounts
		}
		.onAppear {
			sortedAccounts = AccountManager.shared.sortedAccounts
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
		VStack(alignment: .leading) {
			HStack {
				Image(uiImage: account.smallIcon!.image)
					.resizable()
					.frame(width: 25, height: 25)
				TextField(text: Binding(get: { account.nameForDisplay }, set: { account.name = $0 })) {
					Text(account.nameForDisplay)
				}.foregroundColor(.secondary)
				Spacer()
				Toggle(isOn: Binding<Bool>(
					get: { account.isActive },
					set: { account.isActive = $0 }
				)) {
					Text("")
				}
			}
			if account.type != .onMyMac {
				Divider()
					.edgesIgnoringSafeArea(.all)
				HStack {
					Spacer()
					Button {
						// Remove account
					} label: {
						Text("Remove Account")
							.foregroundColor(.red)
							.bold()
					}
					
					Spacer()
				}
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
