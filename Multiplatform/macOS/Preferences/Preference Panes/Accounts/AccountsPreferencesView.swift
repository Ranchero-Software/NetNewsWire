//
//  AccountsPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI
import Account


struct AccountsPreferencesView: View {
	
	@StateObject var viewModel = AccountsPreferenceModel()
	
	@State private var hoverOnAdd: Bool = false
	@State private var hoverOnRemove: Bool = false
	
	var body: some View {
		VStack {
			HStack(alignment: .top, spacing: 10) {
				VStack(alignment: .leading) {
					List(viewModel.sortedAccounts, id: \.accountID, selection: $viewModel.selectedConfiguredAccountID) {
						ConfiguredAccountRow(account: $0)
							.id($0.accountID)
					}.overlay(
						Group {
							bottomButtonStack
						}, alignment: .bottom)
				}
				.frame(width: 225, height: 300, alignment: .leading)
				.border(Color.gray, width: 1)
				VStack(alignment: .leading) {
					EmptyView()
					Spacer()
				}.frame(width: 225, height: 300, alignment: .leading)
			}
			Spacer()
		}.sheet(isPresented: $viewModel.showAddAccountView,
				onDismiss: { viewModel.showAddAccountView.toggle() },
				content: {
					AddAccountView(preferencesModel: viewModel)
				})
	
	}
	
	var bottomButtonStack: some View {
		VStack(alignment: .leading, spacing: 0) {
			Divider()
			HStack(alignment: .center, spacing: 4) {
				Button(action: {
					viewModel.showAddAccountView.toggle()
				}, label: {
					Image(systemName: "plus")
						.font(.title)
						.frame(width: 30, height: 30)
						.overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
									.foregroundColor(hoverOnAdd ? Color.gray.opacity(0.1) : Color.clear))
						.padding(4)
				})
				.buttonStyle(BorderlessButtonStyle())
				.onHover { hovering in
					hoverOnAdd = hovering
				}
				.help("Add Account")
				
				Button(action: {
					if let account = viewModel.sortedAccounts.first(where: { $0.accountID == viewModel.selectedConfiguredAccountID }) {
						AccountManager.shared.deleteAccount(account)
					}
					
				}, label: {
					Image(systemName: "minus")
						.font(.title)
						.frame(width: 30, height: 30)
						.overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
									.foregroundColor(hoverOnRemove ? Color.gray.opacity(0.1) : Color.clear))
						.padding(4)
				})
				.buttonStyle(BorderlessButtonStyle())
				.onHover { hovering in
					hoverOnRemove = hovering
				}
				.disabled(viewModel.selectedAccountIsDefault)
				.help("Delete Account")
				
				Spacer()
			}
			.background(Color.white)
		}
		
		
	}
	
}

struct ConfiguredAccountRow: View {
	
	var account: Account
	
	var body: some View {
		HStack(alignment: .center) {
			if let img = account.smallIcon?.image {
				Image(rsImage: img)
					.resizable()
					.frame(width: 30, height: 30)
					.aspectRatio(contentMode: .fit)
			}
			Text(account.nameForDisplay)
		}.padding(.vertical, 4)
	}
	
}

struct AddAccountPickerRow: View {
	
	var accountType: AccountType
	
	var body: some View {
		HStack {
			if let img = AppAssets.image(for: accountType) {
				Image(rsImage: img)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 15, height: 15)
			}
			
			switch accountType {
				case .onMyMac:
					Text(Account.defaultLocalAccountName)
				case .cloudKit:
					Text("iCloud")
				case .feedbin:
					Text("Feedbin")
				case .feedWrangler:
					Text("FeedWrangler")
				case .freshRSS:
					Text("FreshRSS")
				case .feedly:
					Text("Feedly")
				case .newsBlur:
					Text("NewsBlur")
			}
		}
	}
}





