//
//  SettingsSubscriptionsExportAccountPickerView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsSubscriptionsExportAccountPickerView: View {

	@Environment(\.presentationMode) var presentation
	@State private var selectedAccount: Account?
	@State private var isOPMLExportDocPickerPresented: Bool = false

    var body: some View {
		Form {
			ForEach(AccountManager.shared.sortedAccounts) { account in
				Button(action: {
					self.selectedAccount = account
					self.isOPMLExportDocPickerPresented = true
				}) {
					Text(verbatim: account.nameForDisplay)
				}.buttonStyle(VibrantButtonStyle(alignment: .leading))
			}
		}.sheet(isPresented: $isOPMLExportDocPickerPresented, onDismiss: { self.presentation.wrappedValue.dismiss() }) {
			SettingsSubscriptionsExportDocumentPickerView(account: self.selectedAccount!)
		}
		.navigationBarTitle(Text("Select Account"), displayMode: .inline)
	}
	
}
