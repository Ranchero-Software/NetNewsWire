//
//  SettingsReaderAPIAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Jeremy Beker on 5/28/2019.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Combine
import Account
import RSWeb

struct SettingsReaderAPIAccountView : View {
	@Environment(\.isPresented) private var isPresented
	@ObjectBinding var viewModel: ViewModel
	@State var busy: Bool = false
	@State var error: Text = Text("")

	var body: some View {
		NavigationView {
			List {
				Section(header:
					SettingsAccountLabelView(accountImage: "accountFreshRSS", accountLabel: "FreshRSS").padding()
				)  {
					HStack {
						Text("Email:")
						Divider()
						TextField($viewModel.email)
						.textContentType(.username)
					}
					HStack {
						Text("Password:")
						Divider()
						SecureField($viewModel.password)
					}
					HStack {
						Text("API URL:")
						Divider()
						TextField($viewModel.apiURL)
							.textContentType(.URL)
					}
				}
				Section(footer:
					HStack {
						Spacer()
						error.color(.red)
						Spacer()
					}
					) {
					HStack {
						Spacer()
						Button(action: { self.addAccount() }) {
							if viewModel.isUpdate {
								Text("Update Account")
							} else {
								Text("Add Account")
							}
						}
						.disabled(!viewModel.isValid)
						Spacer()
					}
				}
			}
			.disabled(busy)
			.listStyle(.grouped)
			.navigationBarTitle(Text(""), displayMode: .inline)
			.navigationBarItems(leading:
				Button(action: { self.dismiss() }) { Text("Cancel") }
			)
		}
	}
	
	private func addAccount() {
		
		busy = true
		error = Text("")
		
		let emailAddress = viewModel.email.trimmingCharacters(in: .whitespaces)
		let credentials = Credentials.readerAPIBasicLogin(username: emailAddress, password: viewModel.password)
		guard let apiURL = URL(string: viewModel.apiURL) else {
			self.error = Text("Invalide API URL.")
			return
		}

		Account.validateCredentials(type: viewModel.accountType, credentials: credentials, endpoint: apiURL) { result in
			
			self.busy = false
			
			switch result {
			case .success(let authenticated):
				
				if (authenticated != nil) {
					
					var newAccount = false
					let workAccount: Account
					if self.viewModel.account == nil {
						workAccount = AccountManager.shared.createAccount(type: self.viewModel.accountType)
						newAccount = true
					} else {
						workAccount = self.viewModel.account!
					}
					
					do {
						
						do {
							try workAccount.removeCredentials()
						} catch {}
						
						workAccount.endpointURL = apiURL
						
						try workAccount.storeCredentials(credentials)
						
						if newAccount {
							workAccount.refreshAll() { result in }
						}
						
						self.dismiss()
						
					} catch {
						self.error = Text("Keychain error while storing credentials.")
					}
					
				} else {
					self.error = Text("Invalid email/password combination.")
				}
				
			case .failure:
				self.error = Text("Network error. Try again later.")
			}
			
		}
		
	}
	
	private func dismiss() {
		isPresented?.value = false
	}
	
	class ViewModel: BindableObject {
		let didChange = PassthroughSubject<ViewModel, Never>()
		var accountType: AccountType
		var account: Account? = nil
		
		init(accountType: AccountType) {
			self.accountType = accountType
		}
		
		init(accountType: AccountType, account: Account) {
			self.account = account
			self.accountType = accountType
			if case .basic(let username, let password) = try? account.retrieveCredentials() {
				self.email = username
				self.password = password
			}
		}

		var email: String = "" {
			didSet {
				didChange.send(self)
			}
		}
		var password: String = "" {
			didSet {
				didChange.send(self)
			}
		}
		var apiURL: String = "" {
			didSet {
				didChange.send(self)
			}
		}
		var isUpdate: Bool {
			return account != nil
		}
		
		var isValid: Bool {
			return !email.isEmpty && !password.isEmpty
		}
	}
	
}

#if DEBUG
struct SettingsReaderAPIAccountView_Previews : PreviewProvider {
    static var previews: some View {
		SettingsReaderAPIAccountView(viewModel: SettingsReaderAPIAccountView.ViewModel(accountType: .freshRSS))
    }
}
#endif
