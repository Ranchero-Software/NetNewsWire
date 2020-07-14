//
//  AddAccountView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 13/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct AddAccountView: View {
	
	@Environment(\.presentationMode) private var presentationMode
	@ObservedObject var preferencesModel: AccountsPreferencesModel
	@StateObject private var viewModel = AddAccountModel()

	var body: some View {
		
		VStack(alignment: .leading) {
			Text("Add an Account").font(.headline)
			Form {
				Picker("Account Type",
					   selection: $viewModel.selectedAddAccount,
					   content: {
						ForEach(0..<viewModel.addableAccountTypes.count, content: { i in
							AddAccountPickerRow(accountType: viewModel.addableAccountTypes[i]).tag(viewModel.addableAccountTypes[i])
						})
					   })
				
				
				switch viewModel.selectedAddAccount {
					case .onMyMac:
						addLocalAccountView
					case .cloudKit:
						Text("iCloud")
					case .feedbin:
						userNameAndPasswordView
					case .feedWrangler:
						userNameAndPasswordView
					case .freshRSS:
						userNamePasswordAndAPIUrlView
					case .feedly:
						Text("Feedly")
					case .newsBlur:
						userNameAndPasswordView
				}
				
			}
			Spacer()
			HStack {
				if viewModel.accountIsAuthenticating {
					ProgressView("Adding Account")
				}
				Spacer()
				Button(action: { presentationMode.wrappedValue.dismiss() }, label: {
					Text("Cancel")
				})
				
				if viewModel.selectedAddAccount == .onMyMac {
					Button("Add", action: {
						viewModel.authenticateAccount()
					})
				}
				
				if viewModel.selectedAddAccount != .onMyMac && viewModel.selectedAddAccount != .freshRSS  {
					Button("Add Account", action: {
						viewModel.authenticateAccount()
					})
					.disabled(viewModel.userName.count == 0 || viewModel.password.count == 0)
				}
				
				if viewModel.selectedAddAccount == .freshRSS  {
					Button("Add Account", action: {
						viewModel.authenticateAccount()
					})
					.disabled(viewModel.userName.count == 0 || viewModel.password.count == 0 || viewModel.apiUrl.count == 0)
				}
			}
		}
		.frame(idealWidth: 300, idealHeight: 200, alignment: .top)
		.padding()
		.onChange(of: viewModel.selectedAddAccount) { _ in
			viewModel.resetUserEntries()
		}
		.onChange(of: viewModel.accountAdded) { value in
			if value == true {
				preferencesModel.showAddAccountView = false
			}
		}
		.alert(isPresented: $viewModel.showError) {
			Alert(title: Text("Error Adding Account"),
				  message: Text(viewModel.addAccountError.description),
				  dismissButton: .default(Text("Dismiss"),
										  action: {
											viewModel.addAccountError = .none
										  }))
		}
	}
	
	
	var addLocalAccountView: some View {
		Group {
			TextField("Account Name", text: $viewModel.newLocalAccountName)
				.textFieldStyle(RoundedBorderTextFieldStyle())
			Text("This account stores all of its data on your device. It does not sync.")
				.foregroundColor(.secondary)
				.multilineTextAlignment(.leading)
		}
	}
	
	var userNameAndPasswordView: some View {
		Group {
			TextField("Email", text: $viewModel.userName)
				.textFieldStyle(RoundedBorderTextFieldStyle())
			SecureField("Password", text: $viewModel.password)
				.textFieldStyle(RoundedBorderTextFieldStyle())
		}
	}
	
	var userNamePasswordAndAPIUrlView: some View {
		Group {
			TextField("Email", text: $viewModel.userName)
			SecureField("Password", text: $viewModel.password)
			TextField("API URL", text: $viewModel.apiUrl)
		}.textFieldStyle(RoundedBorderTextFieldStyle())
	}
	
	
}
struct AddAccountView_Previews: PreviewProvider {
	static var previews: some View {
		AddAccountView(preferencesModel: AccountsPreferencesModel())
	}
}
