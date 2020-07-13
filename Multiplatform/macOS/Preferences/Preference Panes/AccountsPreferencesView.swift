//
//  AccountsPreferencesView.swift
//  macOS
//
//  Created by Stuart Breckenridge on 27/6/20.
//

import SwiftUI
import Account

struct AccountPreferencesViewModel {
	
	// Sorted Accounts
	let sortedAccounts = AccountManager.shared.sortedAccounts
	
	// Available Accounts
	let accountTypes: [AccountType] = [.onMyMac, .feedbin, .feedly]
	
	var selectedAccount: Int? = 0
}

struct AccountsPreferencesView: View {
	
	@State private var viewModel = AccountPreferencesViewModel()
	@State private var addAccountViewModel = AccountPreferencesViewModel()
	@State private var showAddAccountView: Bool = false
	@State private var hoverOnAdd: Bool = false
	@State private var hoverOnRemove: Bool = false
	
	var body: some View {
		VStack {
			HStack(alignment: .top, spacing: 10) {
				VStack(alignment: .leading) {
					List(selection: $viewModel.selectedAccount) {
						ForEach(0..<viewModel.sortedAccounts.count, content: { i in
							ConfiguredAccountRow(account: viewModel.sortedAccounts[i])
								.tag(i)
						})
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
		}.sheet(isPresented: $showAddAccountView,
				onDismiss: { showAddAccountView.toggle() },
				content: {
					AddAccountView()
				})
	}
	
	var bottomButtonStack: some View {
		VStack(alignment: .leading, spacing: 0) {
			Divider()
			HStack(alignment: .center, spacing: 4) {
				Button(action: {
					showAddAccountView.toggle()
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
					//
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
				.help("Remove Account")
				
				
				
				Spacer()
			}.background(Color.white)
		}
		
		
	}
	
}

struct ConfiguredAccountRow: View {
	
	var account: Account
	
	var body: some View {
		HStack(alignment: .center) {
			if let img = account.smallIcon?.image {
				Image(rsImage: img)
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
	

struct AddAccountView: View {

	@Environment(\.presentationMode) var presentationMode
	let addableAccountTypes: [AccountType] = [.onMyMac, .feedbin, .feedly]
	@State private var selectedAccount: AccountType = .onMyMac
	@State private var userName: String = ""
	@State private var password: String = ""
	@State private var newLocalAccountName = ""
	
	var body: some View {

		VStack(alignment: .leading) {
			Text("Add an Account").font(.headline)
			Form {
				Picker("Account Type",
					   selection: $selectedAccount,
					   content: {
						ForEach(0..<addableAccountTypes.count, content: { i in
							AddAccountPickerRow(accountType: addableAccountTypes[i]).tag(addableAccountTypes[i])
						})
					   })

				if selectedAccount != .onMyMac {
					TextField("Email", text: $userName)
						.textFieldStyle(RoundedBorderTextFieldStyle())
					SecureField("Password", text: $password)
						.textFieldStyle(RoundedBorderTextFieldStyle())
				}
				
				if selectedAccount == .onMyMac {
					TextField("Account Name", text: $newLocalAccountName)
						.textFieldStyle(RoundedBorderTextFieldStyle())
					Text("This account stores all of its data on your device. It does not sync.")
						.foregroundColor(.secondary)
						.multilineTextAlignment(.leading)
				}
			}
			Spacer()
			HStack {
				Spacer()


				Button(action: { presentationMode.wrappedValue.dismiss() }, label: {
					Text("Cancel")
				})

				if selectedAccount == .onMyMac {
					Button("Add", action: {})
				}

				if selectedAccount != .onMyMac {
					Button("Add Account", action: {})
						.disabled(userName.count == 0 || password.count == 0)
				}


			}
		}
		.frame(idealWidth: 300, idealHeight: 200, alignment: .top)
		.padding()

	}

}


class AddAccountModel: ObservableObject {
	let accountTypes = ["On My Mac", "FeedBin"]
	@Published var selectedAccount = Int?.none
}



