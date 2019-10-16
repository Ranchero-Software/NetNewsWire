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
	@Environment(\.presentationMode) var presentation
	@ObservedObject var viewModel: ViewModel

	@State var busy: Bool = false
	@State var error: String = ""

	var body: some View {
		Form {
			Section(header:
				HStack {
					Spacer()
					SettingsAccountLabelView(accountImage: "accountFreshRSS", accountLabel: "FreshRSS")
						.padding()
						.layoutPriority(1.0)
					Spacer()
				}
			)  {
				TextField("Email", text: $viewModel.email)
					.keyboardType(.emailAddress)
					.textContentType(.emailAddress)
				SecureField("Password", text: $viewModel.password)
				TextField("API URL:", text: $viewModel.apiURL).textContentType(.URL)
			}
			
			Section(footer:
				HStack {
					Spacer()
					Text(verbatim: error).foregroundColor(.red)
					Spacer()
				}
				) {
				Button(action: { self.addAccount() }) {
					if viewModel.isUpdate {
						Text("Update Account")
					} else {
						Text("Add Account")
					}
				}
				.buttonStyle(VibrantButtonStyle(alignment: .center))
				.disabled(!viewModel.isValid)
			}
		}
//			.disabled(busy)
	}
	
	private func addAccount() {
		
		busy = true
		error = ""
		
		let emailAddress = viewModel.email.trimmingCharacters(in: .whitespaces)
		let credentials = Credentials(type: .readerBasic, username: emailAddress, secret: viewModel.password)
		guard let apiURL = URL(string: viewModel.apiURL) else {
			self.error = "Invalid API URL."
			return
		}

		Account.validateCredentials(type: viewModel.accountType, credentials: credentials, endpoint: apiURL) { result in

			self.busy = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.error = "Invalid email/password combination."
					return
				}

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
						try workAccount.removeCredentials(type: .readerBasic)
						try workAccount.removeCredentials(type: .readerAPIKey)
					} catch {}
					
					workAccount.endpointURL = apiURL
					
					try workAccount.storeCredentials(credentials)
					try workAccount.storeCredentials(validatedCredentials)
					
					if newAccount {
						workAccount.refreshAll() { result in }
					}
					
					self.dismiss()
					
				} catch {
					self.error = "Keychain error while storing credentials."
				}
					
			case .failure:
				self.error = "Network error. Try again later."
			}
			
		}
		
	}
	
	private func dismiss() {
		presentation.wrappedValue.dismiss()
	}
	
	class ViewModel: ObservableObject {
		
		let objectWillChange = ObservableObjectPublisher()
		var accountType: AccountType
		var account: Account? = nil
		
		init(accountType: AccountType) {
			self.accountType = accountType
		}
		
		init(account: Account) {
			self.account = account
			self.accountType = account.type
			if let credentials = try? account.retrieveCredentials(type: .readerBasic) {
				self.email = credentials.username
				self.apiURL = account.endpointURL?.absoluteString ?? ""
			}
		}

		var email: String = "" {
			willSet {
				objectWillChange.send()
			}
		}
		var password: String = "" {
			willSet {
				objectWillChange.send()
			}
		}
		var apiURL: String = "" {
			willSet {
				objectWillChange.send()
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
