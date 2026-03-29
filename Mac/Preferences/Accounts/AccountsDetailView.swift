//
//  AccountsDetailView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/19/26.
//

import SwiftUI
import Account

struct AccountsDetailView: View {

	let account: Account
	var onCredentials: (() -> Void)?

	@State private var accountName: String
	@State private var isActive: Bool
	@State private var syncUnreadContent: Bool

	init(account: Account, onCredentials: (() -> Void)? = nil) {
		self.account = account
		self.onCredentials = onCredentials
		_accountName = State(initialValue: account.name ?? "")
		_isActive = State(initialValue: account.isActive)
		_syncUnreadContent = State(initialValue: AccountManager.shared.syncArticleContentForUnreadArticles)
	}

	private var showCredentialsButton: Bool {
		switch account.type {
		case .onMyMac, .cloudKit, .feedly:
			return false
		default:
			return true
		}
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Grid(alignment: .leading, verticalSpacing: 0) {
				GridRow(alignment: .firstTextBaseline) {
					Text("Type:")
						.gridColumnAlignment(.trailing)
					Text(account.defaultName)
				}

				GridRow {
					Color.clear
						.gridCellUnsizedAxes([.horizontal, .vertical])
					Toggle("Active", isOn: $isActive)
						.onChange(of: isActive) {
							account.isActive = isActive
						}
						.padding(.top, 9)
				}

				GridRow(alignment: .firstTextBaseline) {
					Text("Name:")
					TextField("", text: $accountName)
						.frame(width: 150)
						.onSubmit {
							commitName()
						}
						.onChange(of: accountName) {
							commitName()
						}
				}
				.padding(.top, 14)

				GridRow {
					Color.clear
						.gridCellUnsizedAxes([.horizontal, .vertical])
					Text("The name can be anything you want. You can even use emoji. 🎸")
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
						.padding(.top, 1)
				}

				if showCredentialsButton {
					GridRow {
						Color.clear
							.gridCellUnsizedAxes([.horizontal, .vertical])
						Button("Credentials") {
							onCredentials?()
						}
						.padding(.top, 12)
					}
				}
			}

			if account.type == .cloudKit {
				Toggle("Sync content of unread articles", isOn: $syncUnreadContent)
					.onChange(of: syncUnreadContent) {
						AccountManager.shared.syncArticleContentForUnreadArticles = syncUnreadContent
					}
					.padding(.top, 12)

				Text("Syncing article content increases iCloud storage use, sync time, and battery use.\n\nArticle status and the content of starred articles are always synced.")
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
					.padding(.top, 4)
					.padding(.leading, 21)
			}
		}
		.padding(20)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}

	private func commitName() {
		if accountName.isEmpty {
			account.name = nil
		} else {
			account.name = accountName
		}
	}
}
