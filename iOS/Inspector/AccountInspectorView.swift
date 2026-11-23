//
//  AccountInspectorView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 11/14/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI
import RSCore
import Account

/// An account’s name, active state, credentials, and removal.
struct AccountInspectorView: View {

	let account: Account
	/// Shown as a sheet with a Done button, rather than pushed onto Settings.
	let isModal: Bool

	@Environment(\.dismiss) private var dismiss
	@State private var name: String
	@State private var isActive: Bool
	@State private var syncContentOfUnreadArticles = AccountManager.shared.syncArticleContentForUnreadArticles
	@State private var isShowingCredentials = false
	@State private var isShowingRemoveConfirmation = false
	@State private var isShowingLimitationsAndSolutions = false

	init(account: Account, isModal: Bool) {
		self.account = account
		self.isModal = isModal
		self._name = State(initialValue: account.name ?? "")
		self._isActive = State(initialValue: account.isActive)
	}

	var body: some View {
		List {
			Section {
				TextField(account.defaultName, text: $name)
					.textInputAutocapitalization(.words)
				Toggle(String(localized: "Active", comment: "Active"), isOn: $isActive)
			} header: {
				AccountIconHeader(accountType: account.type)
			}
			if showsCredentials {
				Section {
					Button(String(localized: "Credentials", comment: "Credentials")) {
						isShowingCredentials = true
					}
				}
			}
			if showsSyncContent {
				Section {
					Toggle(String(localized: "Sync Content of Unread Articles", comment: "Sync Content of Unread Articles"), isOn: $syncContentOfUnreadArticles)
				} footer: {
					Text("Syncing article content increases iCloud storage use, sync time, and battery use.\n\nArticle status and the content of starred articles are always synced.", comment: "Sync content of unread articles footer")
				}
			}
			if showsRemoveAccount {
				Section {
					Button(role: .destructive) {
						isShowingRemoveConfirmation = true
					} label: {
						Text("Remove Account", comment: "Remove Account")
							.frame(maxWidth: .infinity)
					}
				} footer: {
					if account.type == .cloudKit {
						Button(String(localized: "How to Optimize iCloud Syncing", comment: "Help link")) {
							isShowingLimitationsAndSolutions = true
						}
						.font(.subheadline)
						.foregroundStyle(.tint)
						.frame(maxWidth: .infinity)
					}
				}
			}
		}
		.settingsAccentTint()
		.navigationTitle(account.nameForDisplay)
		.toolbar {
			if isModal {
				ToolbarItem(placement: .confirmationAction) {
					doneButton
				}
			}
		}
		.onChange(of: name) {
			saveName()
		}
		.onChange(of: isActive) {
			account.isActive = isActive
		}
		.onChange(of: syncContentOfUnreadArticles) {
			AccountManager.shared.syncArticleContentForUnreadArticles = syncContentOfUnreadArticles
		}
		.sheet(isPresented: $isShowingCredentials) {
			CredentialsAccountView(accountType: account.type, account: account, didAddAccount: nil)
		}
		.sheet(isPresented: $isShowingLimitationsAndSolutions) {
			SafariView(url: CloudKitWebDocumentation.limitationsAndSolutionsURL)
		}
		.alert(String(localized: "Remove Account", comment: "Remove Account"), isPresented: $isShowingRemoveConfirmation) {
			Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) {
			}
			Button(String(localized: "Remove", comment: "Remove"), role: .destructive) {
				removeAccount()
			}
		} message: {
			Text(removeAccountMessage)
		}
	}
}

// MARK: - Private

private extension AccountInspectorView {

	var isDefaultAccount: Bool {
		account == AccountManager.shared.defaultAccount
	}

	var showsCredentials: Bool {
		!isDefaultAccount && CredentialsAccountView.accountTypes.contains(account.type)
	}

	var showsSyncContent: Bool {
		!isDefaultAccount && account.type == .cloudKit
	}

	var showsRemoveAccount: Bool {
		!isDefaultAccount
	}

	var removeAccountMessage: String {
		switch account.type {
		case .feedly:
			NSLocalizedString("Are you sure you want to remove this account? NetNewsWire will no longer be able to access articles and feeds unless the account is added again.", comment: "Log Out and Remove Account")
		default:
			NSLocalizedString("Are you sure you want to remove this account? This cannot be undone.", comment: "Remove Account")
		}
	}

	@ViewBuilder var doneButton: some View {
		if #available(iOS 26, *) {
			Button(role: .confirm) {
				dismiss()
			}
		} else {
			Button(String(localized: "Done", comment: "Done")) {
				dismiss()
			}
		}
	}

	func saveName() {
		account.name = name.isEmpty ? nil : name
	}

	func removeAccount() {
		AccountManager.shared.deleteAccount(account)
		dismiss()
	}
}
