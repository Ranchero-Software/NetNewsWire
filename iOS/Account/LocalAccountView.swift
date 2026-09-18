//
//  LocalAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 9/18/26.
//

import SwiftUI
import Account

/// Sheet for adding an On My Device account.
struct LocalAccountView: View {

	let didAddAccount: () -> Void

	@Environment(\.dismiss) private var dismiss
	@State private var name = ""
	@FocusState private var isNameFieldFocused: Bool

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField(NSLocalizedString("Name", comment: "Local account name placeholder"), text: $name)
						.textInputAutocapitalization(.words)
						.focused($isNameFieldFocused)
						.onSubmit {
							isNameFieldFocused = false
						}
				} header: {
					AccountIconHeader(accountType: .onMyMac)
				}
				Section {
					Button(NSLocalizedString("Add Account", comment: "Add Account")) {
						addAccount()
					}
					.frame(maxWidth: .infinity)
				} footer: {
					Text(NSLocalizedString("Local accounts do not sync your feeds across devices.", comment: "Local"))
						.multilineTextAlignment(.center)
						.frame(maxWidth: .infinity)
				}
			}
			.navigationTitle(Text(verbatim: AccountType.onMyMac.displayName))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
						dismiss()
					}
				}
			}
		}
	}

	private func addAccount() {
		let account = AccountManager.shared.createAccount(type: .onMyMac)
		account.name = name
		dismiss()
		didAddAccount()
	}
}
