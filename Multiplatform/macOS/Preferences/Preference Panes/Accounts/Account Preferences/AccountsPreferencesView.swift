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
				listOfAccounts
				
				AccountDetailView(viewModel: viewModel)
				.frame(height: 300, alignment: .leading)
			}
			Spacer()
		}
		.sheet(isPresented: $viewModel.showSheet,
				onDismiss: { viewModel.sheetToShow = .none },
				content: {
					switch viewModel.sheetToShow {
					case .addAccountPicker:
						AddAccountView(accountToAdd: $viewModel.sheetToShow)
					case .credentials:
						EditAccountCredentialsView(viewModel: viewModel)
					case .none:
						EmptyView()
					case .addSelectedAccount(let type):
						switch type {
						case .onMyMac:
							AddLocalAccountView()
						case .feedbin:
							AddFeedbinAccountView()
						case .cloudKit:
							AddCloudKitAccountView()
						case .feedWrangler:
							AddFeedWranglerAccountView()
						case .newsBlur:
							AddNewsBlurAccountView()
						case .feedly:
							AddFeedlyAccountView()
						default:
							AddReaderAPIAccountView(accountType: type)
						}
					}
				})
		.alert(isPresented: $viewModel.showDeleteConfirmation, content: {
			Alert(title: Text("Delete \(viewModel.account!.nameForDisplay)?"),
				  message: Text("Are you sure you want to delete the account \"\(viewModel.account!.nameForDisplay)\"?  This can not be undone."),
				  primaryButton: .destructive(Text("Delete"), action: {
					AccountManager.shared.deleteAccount(viewModel.account!)
					viewModel.showDeleteConfirmation = false
				  }),
				  secondaryButton: .cancel({
					viewModel.showDeleteConfirmation = false
				  }))
		})
	}
	
	var listOfAccounts: some View {
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
	}
	
	var bottomButtonStack: some View {
		VStack(alignment: .leading, spacing: 0) {
			Divider()
			HStack(alignment: .center, spacing: 4) {
				Button(action: {
					viewModel.sheetToShow = .addAccountPicker
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
					viewModel.showDeleteConfirmation = true
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
			.background(Color.init(.windowBackgroundColor))
		}
	}
	
}
