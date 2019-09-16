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
	@Environment(\.presentationMode) var presentation
	@ObservedObject var viewModel: ViewModel
	@State private var accountType: AccountType = nil
	@State private var isDeleteAlertPresented = false

    var body: some View {
		Form {
			Section {
				HStack {
					TextField("Name", text: $viewModel.name)
				}
				Toggle(isOn: $viewModel.isActive) {
					Text("Active")
				}
			}
			if viewModel.isCreditialsAvailable {
				Section {
					Button(action: {
						self.accountType = self.viewModel.account.type
					}) {
						Text("Credentials")
					}
				}
				.sheet(item: $accountType) { type in
					if type == .feedbin {
						self.settingsFeedbinAccountView
					}
					if type == .freshRSS {
						self.settingsReaderAPIAccountView
					}
				}
			}
			if viewModel.isDeletable {
				Section {
					Button(action: {
						self.isDeleteAlertPresented.toggle()
					}) {
						Text("Delete Account").foregroundColor(.red)
					}
					.alert(isPresented: $isDeleteAlertPresented) {
						Alert(title: Text("Are you sure you want to delete \"\(viewModel.nameForDisplay)\"?"),
							primaryButton: Alert.Button.default(Text("Delete"), action: {
								self.viewModel.delete()
								self.presentation.wrappedValue.dismiss()
							}),
							secondaryButton: Alert.Button.cancel())
					}
				}
			}
		}
		.buttonStyle(VibrantButtonStyle(alignment: .center))
		.navigationBarTitle(Text(verbatim: viewModel.nameForDisplay), displayMode: .inline)

	}
	
	var settingsFeedbinAccountView: SettingsFeedbinAccountView {
		let feedbinViewModel = SettingsFeedbinAccountView.ViewModel(account: viewModel.account)
		return SettingsFeedbinAccountView(viewModel: feedbinViewModel)
	}
	
	var settingsReaderAPIAccountView: SettingsReaderAPIAccountView {
		let readerAPIModel = SettingsReaderAPIAccountView.ViewModel(account: viewModel.account)
		return SettingsReaderAPIAccountView(viewModel: readerAPIModel)
	}

	class ViewModel: ObservableObject {
		
		let objectWillChange = ObservableObjectPublisher()

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
				objectWillChange.send()
				account.name = newValue.isEmpty ? nil : newValue
			}
		}
		
		var isActive: Bool {
			get {
				account.isActive
			}
			set {
				objectWillChange.send()
				account.isActive = newValue
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
			ActivityManager.cleanUp(account)
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
