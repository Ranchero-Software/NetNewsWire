//
//  AddAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 9/18/26.
//

import SwiftUI
import AuthenticationServices
import RSCore
import Account

/// The list of account types the user picks from. Pushed onto the Settings navigation stack.
struct AddAccountView: View {

	/// Window the Feedly OAuth sheet attaches to. Nil is tolerated by the operation.
	let presentationAnchor: ASPresentationAnchor?
	/// Called after an account is added so the host can pop this screen.
	let didAddAccount: () -> Void

	@State private var presentedSheet: AccountSheet?
	@State private var errorMessage: String?
	@State private var oauthHandler = OAuthAuthorizationHandler()

	private static let iconSize: CGFloat = 25
	private static let rowSpacing: CGFloat = 16

	private enum AccountGroup: Int, CaseIterable {
		case local
		case icloud
		case web
		case selfhosted

		var header: String {
			switch self {
			case .local:
				return NSLocalizedString("Local", comment: "Local Account")
			case .icloud:
				return NSLocalizedString("iCloud", comment: "iCloud Account")
			case .web:
				return NSLocalizedString("Web", comment: "Web Account")
			case .selfhosted:
				return NSLocalizedString("Self-hosted", comment: "Self hosted Account")
			}
		}

		var footer: String {
			switch self {
			case .local:
				return NSLocalizedString("Local accounts do not sync your feeds across devices.", comment: "Local")
			case .icloud:
				return NSLocalizedString("Your iCloud account syncs your feeds across your Mac and iOS devices.", comment: "iCloud Account")
			case .web:
				return NSLocalizedString("Web accounts sync your feeds across all your devices.", comment: "Web Account")
			case .selfhosted:
				return NSLocalizedString("Self-hosted accounts sync your feeds across all your devices.", comment: "Self hosted Account")
			}
		}

		var accountTypes: [AccountType] {
			switch self {
			case .local:
				return [.onMyMac]
			case .icloud:
				return [.cloudKit]
			case .web:
				return [.bazQux, .feedbin, .feedly, .inoreader, .newsBlur, .theOldReader]
			case .selfhosted:
				return [.freshRSS]
			}
		}
	}

	private struct AccountSheet: Identifiable {
		let accountType: AccountType

		var id: Int {
			accountType.rawValue
		}
	}

	var body: some View {
		List {
			ForEach(visibleGroups, id: \.self) { group in
				Section {
					ForEach(visibleAccountTypes(in: group), id: \.rawValue) { accountType in
						accountRow(accountType)
					}
				} header: {
					Text(group.header)
				} footer: {
					Text(group.footer)
				}
			}
		}
		.navigationTitle(NSLocalizedString("Add Account", comment: "Add Account"))
		.sheet(item: $presentedSheet) { sheet in
			switch sheet.accountType {
			case .onMyMac:
				LocalAccountView(didAddAccount: didAddAccount)
			case .cloudKit:
				CloudKitAccountView(didAddAccount: didAddAccount)
			default:
				CredentialsAccountView(accountType: sheet.accountType, account: nil, didAddAccount: didAddAccount)
			}
		}
		.alert(NSLocalizedString("Error", comment: "Error"), isPresented: isShowingError) {
			Button(NSLocalizedString("OK", comment: "OK button")) {
				errorMessage = nil
			}
		} message: {
			Text(verbatim: errorMessage ?? "")
		}
	}

	private func accountRow(_ accountType: AccountType) -> some View {
		Button {
			select(accountType)
		} label: {
			HStack(spacing: Self.rowSpacing) {
				Image(uiImage: Assets.accountImage(accountType))
					.resizable()
					.scaledToFit()
					.frame(width: Self.iconSize, height: Self.iconSize)
				Text(verbatim: accountType.displayName)
			}
		}
		.foregroundStyle(.primary)
		.disabled(isDisabled(accountType))
	}

	/// Groups with at least one account type to show. Developer builds hide the restricted types, as the Mac app does.
	private var visibleGroups: [AccountGroup] {
		AccountGroup.allCases.filter { !visibleAccountTypes(in: $0).isEmpty }
	}

	private func visibleAccountTypes(in group: AccountGroup) -> [AccountType] {
		group.accountTypes.filter { !(AppDefaults.shared.isDeveloperBuild && $0.isDeveloperRestricted) }
	}

	private func isDisabled(_ accountType: AccountType) -> Bool {
		accountType == .cloudKit && AccountManager.shared.hasiCloudAccount
	}

	private var isShowingError: Binding<Bool> {
		Binding {
			errorMessage != nil
		} set: { isShowing in
			if !isShowing {
				errorMessage = nil
			}
		}
	}

	private func select(_ accountType: AccountType) {
		switch accountType {
		case .feedly:
			startOAuth(for: accountType)
		default:
			presentedSheet = AccountSheet(accountType: accountType)
		}
	}

	private func startOAuth(for accountType: AccountType) {
		oauthHandler.didCreateAccount = { account in
			account.triggerRefreshAll()
			didAddAccount()
		}
		oauthHandler.didFail = { error in
			errorMessage = error.localizedDescription
		}

		let operation = OAuthAccountAuthorizationOperation(accountType: accountType)
		operation.delegate = oauthHandler
		operation.presentationAnchor = presentationAnchor
		MainThreadOperationQueue.shared.add(operation)
	}
}

/// Forwards the OAuth operation’s delegate callbacks to closures, since a View can’t be the delegate.
@MainActor private final class OAuthAuthorizationHandler: OAuthAccountAuthorizationOperationDelegate {

	var didCreateAccount: ((Account) -> Void)?
	var didFail: ((Error) -> Void)?

	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account) {
		didCreateAccount?(account)
	}

	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error) {
		didFail?(error)
	}
}
