//
//  SettingsDetailAccountView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/13/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Combine
import Account
import RSWeb

struct SettingsDetailAccountView : View {
	@ObjectBinding var viewModel: ViewModel
	@State private var verifyDelete = false
	@State private var showFeedbinCredentials = false
	
    var body: some View {
		Form {
			Section {
				HStack {
					Text("Name")
					Divider()
					TextField($viewModel.name, placeholder: Text("(Optional)"))
				}
				Toggle(isOn: $viewModel.isActive) {
					Text("Active")
				}
			}
			if viewModel.isCreditialsAvailable {
				Section {
					HStack {
						Spacer()
						Button(action: {
							self.showFeedbinCredentials = true
						}) {
							Text("Credentials")
						}
						.presentation(showFeedbinCredentials ? feedbinCredentialsModal : nil)
						.onDisappear() { self.showFeedbinCredentials = false }
						Spacer()
					}
				}
			}
			if viewModel.isDeletable {
				Section {
					HStack {
						Spacer()
						Button(action: {
							self.verifyDelete = true
						}) {
							Text("Delete Account")
								.foregroundColor(.red)
						}
						.presentation($verifyDelete) {
							Alert(title: Text("Are you sure you want to delete \"\(viewModel.nameForDisplay)\"?"),
								  primaryButton: Alert.Button.default(Text("Delete"), onTrigger: { self.viewModel.delete() }),
								  secondaryButton: Alert.Button.cancel())
						}
						Spacer()
					}
				}
			}
		}
		.navigationBarTitle(Text(verbatim: viewModel.nameForDisplay), displayMode: .inline)

	}
	
	var feedbinCredentialsModal: Modal {
		let feedbinViewModel = SettingsFeedbinAccountView.ViewModel(account: viewModel.account)
		return Modal(SettingsFeedbinAccountView(viewModel: feedbinViewModel))
	}
	
	class ViewModel: BindableObject {
		let didChange = PassthroughSubject<ViewModel, Never>()
		let account: Account
		
		init(_ account: Account) {
			self.account = account
		}
		
		var nameForDisplay: String {
			account.nameForDisplay
		}
		
		var name: String {
			get {
				account.name ?? ""
			}
			set {
				account.name = newValue.isEmpty ? nil : newValue
				didChange.send(self)
			}
		}
		
		var isActive: Bool {
			get {
				account.isActive
			}
			set {
				account.isActive = newValue
				didChange.send(self)
			}
		}
		
		var isCreditialsAvailable: Bool {
			return account.type != .onMyMac
		}
		
		var isDeletable: Bool {
			return AccountManager.shared.defaultAccount != account
		}
		
		func delete() {
			AccountManager.shared.deleteAccount(account)
			ActivityManager.shared.cleanUp(account)
		}
	}
}

#if DEBUG
struct SettingsDetailAccountView_Previews : PreviewProvider {
    static var previews: some View {
		let viewModel = SettingsDetailAccountView.ViewModel(AccountManager.shared.defaultAccount)
        return SettingsDetailAccountView(viewModel: viewModel)
    }
}
#endif
