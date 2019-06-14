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
	@Environment(\.isPresented) private var isPresented
	@ObjectBinding var viewModel: ViewModel
	@State var busy: Bool = false
	@State var error: Text = Text("")
	var account: Account? = nil
	
	var body: some View {
		NavigationView {
			List {
				Section(header:
					SettingsAccountLabelView(accountImage: "accountFeedbin", accountLabel: "Feedbin").padding()
				)  {
					HStack {
						Spacer()
						TextField($viewModel.email, placeholder: Text("Email"))
							.textContentType(.username)
						Spacer()
					}
					HStack {
						Spacer()
						SecureField($viewModel.password, placeholder: Text("Password"))
						Spacer()
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
							Text("Add Account")
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

		let emailAddress = viewModel.email.trimmingCharacters(in: .whitespaces)
		let credentials = Credentials.basic(username: emailAddress, password: viewModel.password)

		Account.validateCredentials(type: .feedbin, credentials: credentials) { result in
			
			self.busy = false
			
			switch result {
			case .success(let authenticated):
				
				if authenticated {
					
					var newAccount = false
					let workAccount: Account
					if self.account == nil {
						workAccount = AccountManager.shared.createAccount(type: .feedbin)
						newAccount = true
					} else {
						workAccount = self.account!
					}
					
					do {
						
						do {
							try workAccount.removeBasicCredentials()
						} catch {}
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
