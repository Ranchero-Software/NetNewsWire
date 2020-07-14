//
//  AccountsPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI
import Account


struct AccountsPreferencesView: View {
	
	@StateObject var viewModel = AccountsPreferencesModel()
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
				.frame(width: 160, height: 300, alignment: .leading)
				.border(Color.gray, width: 1)
				
				EditAccountView(viewModel: viewModel)
				.frame(height: 300, alignment: .leading)
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
