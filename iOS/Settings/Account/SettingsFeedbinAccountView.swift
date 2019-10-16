//
//  SettingsFeedbinAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Combine
import Account
import RSWeb

struct SettingsFeedbinAccountView : View {
	@Environment(\.presentationMode) var presentation
	@ObservedObject var viewModel: ViewModel
	@State var busy: Bool = false
	@State var error: String = ""

	var body: some View {
		Form {
			Section(header:
				HStack {
					Spacer()
					SettingsAccountLabelView(accountImage: "accountFeedbin", accountLabel: "Feedbin")
						.padding()
						.layoutPriority(1.0)
					Spacer()
				}
			)  {
				TextField("Email", text: $viewModel.email)
					.keyboardType(.emailAddress)
					.textContentType(.emailAddress)
				PasswordField(password: $viewModel.password)
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
//		.disabled(busy)  // Maybe someday we can do this, but right now it crashes on the iPad
		.navigationBarTitle(Text(""), displayMode: .inline)
	}
	
	private func addAccount() {
		
		busy = true
		error = ""
		
		let emailAddress = viewModel.email.trimmingCharacters(in: .whitespaces)
		let credentials = Credentials(type: .basic, username: emailAddress, secret: viewModel.password)

		Account.validateCredentials(type: .feedbin, credentials: credentials) { result in

			self.busy = false

			switch result {
			case .success(let authenticated):

				if (authenticated != nil) {

					var newAccount = false
					let workAccount: Account
					if self.viewModel.account == nil {
						workAccount = AccountManager.shared.createAccount(type: .feedbin)
						newAccount = true
					} else {
						workAccount = self.viewModel.account!
					}

					do {

						do {
							try workAccount.removeCredentials(type: .basic)
						} catch {}
						try workAccount.storeCredentials(credentials)

						if newAccount {
							workAccount.refreshAll() { result in }
						}

						self.dismiss()

					} catch {
						self.error = "Keychain error while storing credentials."
					}

				} else {
					self.error = "Invalid email/password combination."
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
		var account: Account? = nil
		
		init() {
		}
		
		init(account: Account) {
			self.account = account
			if let credentials = try? account.retrieveCredentials(type: .basic) {
				self.email = credentials.username
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
		
		var isUpdate: Bool {
			return account != nil
		}
		
		var isValid: Bool {
			return !email.isEmpty && !password.isEmpty
		}
	}
	
}

#if DEBUG
struct SettingsFeedbinAccountView_Previews : PreviewProvider {
    static var previews: some View {
		SettingsFeedbinAccountView(viewModel: SettingsFeedbinAccountView.ViewModel())
    }
}
#endif
