//
//  AddAccountListView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 15/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore

public final class AddAccountListViewModel: ObservableObject, OAuthAccountAuthorizationOperationDelegate {
	
	@Published public var showAddAccountSheet: (Bool, accountType: AccountType) = (false, .onMyMac)
	@Published public var showAddAccountError: (Error?, Bool) = (nil, false)
	public var webAccountTypes: [AccountType] {
		if AppDefaults.shared.isDeveloperBuild {
			return [.bazQux, .feedbin, .feedly, .inoreader, .newsBlur, .theOldReader]
				.filter({ $0.isDeveloperRestricted == false })
		} else {
			return [.bazQux, .feedbin, .feedly, .inoreader, .newsBlur, .theOldReader]
		}
	}
	
	public var rootViewController: UIViewController? {
		var currentKeyWindow: UIWindow? {
			UIApplication.shared.connectedScenes
			  .filter { $0.activationState == .foregroundActive }
			  .map { $0 as? UIWindowScene }
			  .compactMap { $0 }
			  .first?.windows
			  .filter { $0.isKeyWindow }
			  .first
		  }

		  var rootViewController: UIViewController? {
			currentKeyWindow?.rootViewController
		  }
		
		return rootViewController
	}
	
	public func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account) {
		account.refreshAll { [weak self] result in
			switch result {
			case .success:
				break
			case .failure(let error):
				guard let viewController = self?.rootViewController else {
					return
				}
				viewController.presentError(error)
			}
		}
	}
	
	public func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error) {
		showAddAccountError = (error, true)
	}
}

struct AddAccountListView: View {
    
	@Environment(\.dismiss) var dismiss
	@StateObject private var viewModel = AddAccountListViewModel()
	
	
	var body: some View {
		NavigationView {
			List {
				localAccountSection
				cloudKitSection
				webAccountSection
				selfHostedSection
			}
			.navigationTitle(Text("navigation.title.add-account", comment: "Add Account"))
			.navigationBarTitleDisplayMode(.inline)
			.listItemTint(.primary)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button(role: .cancel) {
						dismiss()
					} label: {
						Text("button.title.cancel", comment: "Button title")
					}
				}
			}
			.sheet(isPresented: $viewModel.showAddAccountSheet.0) {
				switch viewModel.showAddAccountSheet.accountType {
				case .onMyMac:
					LocalAddAccountView()
				case .cloudKit:
					CloudKitAddAccountView()
				case .newsBlur:
					NewsBlurAddAccountView()
				case .freshRSS, .inoreader, .bazQux, .theOldReader:
					ReaderAPIAddAccountView(accountType: viewModel.showAddAccountSheet.accountType, account: nil)
				default:
					Text(viewModel.showAddAccountSheet.accountType.localizedAccountName())
				}
			}
			.alert(Text("alert.title.error", comment: "Error"),
				   isPresented: $viewModel.showAddAccountError.1,
				   actions: { },
				   message: {
				Text(verbatim: "\(viewModel.showAddAccountError.0?.localizedDescription ?? "Unknown Error")")
			})
			.dismissOnAccountAdd()
		}
    }
	
	var localAccountSection: some View {
		Section {
			Button {
				viewModel.showAddAccountSheet = (true, .onMyMac)
			} label: {
				Label {
					Text(verbatim: AccountType.onMyMac.localizedAccountName())
						.foregroundColor(.primary)
				} icon: {
					Image(uiImage: AppAssets.image(for: .onMyMac)!)
						.resizable()
						.frame(width: 30, height: 30)
				}
			}
		} header: {
			Text("label.text.local-account", comment: "Local Account")
		} footer: {
			Text("label.text.local-account-explainer", comment: "Local accounts do not sync your feeds across devices")
		}
	}
	
	var cloudKitSection: some View {
		Section {
			Button {
				viewModel.showAddAccountSheet = (true, .cloudKit)
			} label: {
				Label {
					Text(AccountType.cloudKit.localizedAccountName())
						.foregroundColor(interactionDisabled(for: .cloudKit) ? .secondary : .primary)
				} icon: {
					Image(uiImage: AppAssets.image(for: .cloudKit)!)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 30, height: 30)
				}
			}
			.disabled(interactionDisabled(for: .cloudKit))
		} header: {
			Text("label.text.cloudkit-account", comment: "iCloud")
		} footer: {
			Text("label.text.cloudkit-account-footer", comment: "Your iCloud account syncs your feeds across your Mac and iOS devices")
		}
	}
	
	var webAccountSection: some View {
		Section {
			ForEach(viewModel.webAccountTypes, id: \.self) { webAccount in
				Button {
					if webAccount == .feedly {
						let addAccount = OAuthAccountAuthorizationOperation(accountType: .feedly)
						addAccount.delegate = viewModel
						addAccount.presentationAnchor = viewModel.rootViewController?.view.window
						MainThreadOperationQueue.shared.add(addAccount)
					} else {
						viewModel.showAddAccountSheet = (true, webAccount)
					}
					
				} label: {
					Label {
						Text(webAccount.localizedAccountName())
							.foregroundColor(.primary)
					} icon: {
						Image(uiImage: AppAssets.image(for: webAccount)!)
							.resizable()
							.aspectRatio(contentMode: .fit)
							.frame(width: 30, height: 30)
					}
				}
			}
		} header: {
			Text("label.text.web-account", comment: "Web Account")
		} footer: {
			Text("label.text.web-account-explainer", comment: "Web accounts sync your feeds across all your devices")
		}
	}
	
	var selfHostedSection: some View {
		Section {
			Button {
				viewModel.showAddAccountSheet = (true, .freshRSS)
			} label: {
				Label {
					Text(AccountType.freshRSS.localizedAccountName())
						.foregroundColor(.primary)
				} icon: {
					Image(uiImage: AppAssets.image(for: .freshRSS)!)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 30, height: 30)
				}
			}
		} header: {
			Text("label.text.self-hosted-accounts", comment: "Self-Hosted Accounts")
		} footer: {
			Text("label.text.self-hosted-accounts-explainer", comment: "Self-hosted accounts sync your feeds across all your devices")
		}
	}
	
	private func interactionDisabled(for accountType: AccountType) -> Bool {
		if accountType == .cloudKit {
			if AccountManager.shared.accounts.contains(where: { $0.type == .cloudKit }) {
				return true
			}
			return AppDefaults.shared.isDeveloperBuild
		}
	
		return accountType.isDeveloperRestricted
	}
	
}
