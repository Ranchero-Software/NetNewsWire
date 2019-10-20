//
//  SettingsSubscriptionsImportAccountPickerView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsSubscriptionsImportAccountPickerView: View {

	@Environment(\.presentationMode) var presentation
	@State private var selectedAccount: Account?
	@State private var isOPMLImportDocPickerPresented: Bool = false

    var body: some View {
		Form {
			ForEach(AccountManager.shared.sortedActiveAccounts) { account in
				Button(action: {
					self.selectedAccount = account
					self.isOPMLImportDocPickerPresented = true
				}) {
					Text(verbatim: account.nameForDisplay)
				}.buttonStyle(VibrantButtonStyle(alignment: .leading))
			}
		}.sheet(isPresented: $isOPMLImportDocPickerPresented, onDismiss: { self.presentation.wrappedValue.dismiss() }) {
			SettingsSubscriptionsImportDocumentPickerView(account: self.selectedAccount!)
		}
		.navigationBarTitle(Text("Select Account"), displayMode: .inline)
	}
	
}
