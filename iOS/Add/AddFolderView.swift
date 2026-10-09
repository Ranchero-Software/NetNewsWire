//
//  AddFolderView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 9/18/26.
//

import SwiftUI
import RSCore
import Account

/// Sheet for adding a folder to an account.
struct AddFolderView: View {

	@Environment(\.dismiss) private var dismiss
	@State private var name = ""
	@State private var selectedAccountID = ""
	@State private var isAdding = false
	@State private var errorMessage: String?
	@FocusState private var isNameFieldFocused: Bool

	/// Accounts that allow folders, in sidebar order.
	private let accounts: [Account]

	init() {
		let accounts = AccountManager.shared.sortedActiveAccounts.filter { !$0.behaviors.contains(.disallowFolderManagement) }
		self.accounts = accounts

		let rememberedAccount = accounts.first { $0.accountID == AppDefaults.shared.addFolderAccountID }
		self._selectedAccountID = State(initialValue: (rememberedAccount ?? accounts.first)?.accountID ?? "")
	}

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField(NSLocalizedString("Name", comment: "Name field placeholder"), text: $name)
						.textInputAutocapitalization(.words)
						.focused($isNameFieldFocused)
						.onSubmit {
							isNameFieldFocused = false
						}
				}
				Section {
					if accounts.count > 1 {
						Picker(NSLocalizedString("Account", comment: "Account"), selection: $selectedAccountID) {
							ForEach(accounts, id: \.accountID) { account in
								Text(verbatim: account.nameForDisplay)
									.tag(account.accountID)
							}
						}
					} else if let account = accounts.first {
						LabeledContent(NSLocalizedString("Account", comment: "Account"), value: account.nameForDisplay)
					}
				}
			}
			.navigationTitle(NSLocalizedString("Add Folder", comment: "Add Folder"))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
						dismiss()
					}
					.disabled(isAdding)
				}
				ToolbarItem(placement: .confirmationAction) {
					if isAdding {
						ProgressView()
					} else {
						Button(NSLocalizedString("Add", comment: "Add button")) {
							Task {
								await addFolder()
							}
						}
						.disabled(!canAdd)
					}
				}
			}
			.interactiveDismissDisabled(isAdding)
			.errorAlert(message: $errorMessage)
			.onAppear {
				isNameFieldFocused = true
			}
		}
	}

	private var selectedAccount: Account? {
		accounts.first { $0.accountID == selectedAccountID }
	}

	private var trimmedName: String {
		name.trimmingWhitespace
	}

	private var canAdd: Bool {
		!trimmedName.isEmpty && selectedAccount != nil
	}

	private func addFolder() async {
		guard let selectedAccount else {
			return
		}
		AppDefaults.shared.addFolderAccountID = selectedAccount.accountID

		isAdding = true
		defer {
			isAdding = false
		}

		do {
			try await selectedAccount.addFolder(trimmedName)
			dismiss()
		} catch {
			errorMessage = error.localizedDescription
		}
	}
}
