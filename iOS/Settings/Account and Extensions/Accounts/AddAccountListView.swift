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
			.navigationTitle(Text("ADD_ACCOUNT", tableName: "Settings"))
			.navigationBarTitleDisplayMode(.inline)
			.listItemTint(.primary)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button(role: .cancel) {
						dismiss()
					} label: {
						Text("CANCEL_BUTTON_TITLE", tableName: "Buttons")
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
			.alert(Text("ERROR_TITLE", tableName: "Errors"),
				   isPresented: $viewModel.showAddAccountError.1, actions: {
				Button {
					//
				} label: {
					Text("DISMISS_BUTTON_TITLE", tableName: "Buttons")
				}
			}, message: {
				Text("\(viewModel.showAddAccountError.0?.localizedDescription ?? "Unknown Error")")
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
					Text(AccountType.onMyMac.localizedAccountName())
						.foregroundColor(.primary)
				} icon: {
					Image(uiImage: AppAssets.image(for: .onMyMac)!)
						.resizable()
						.frame(width: 30, height: 30)
				}
			}
		} header: {
			Text("ADD_LOCAL_ACCOUNT_HEADER", tableName: "Settings")
		} footer: {
			Text("ADD_LOCAL_ACCOUNT_FOOTER", tableName: "Settings")
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
			Text("ADD_CLOUDKIT_ACCOUNT_HEADER", tableName: "Settings")
		} footer: {
			Text("ADD_CLOUDKIT_ACCOUNT_FOOTER", tableName: "Settings")
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
			Text("ADD_WEB_ACCOUNT_HEADER", tableName: "Settings")
		} footer: {
			Text("ADD_WEB_ACCOUNT_FOOTER", tableName: "Settings")
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
			Text("ADD_SELFHOSTED_ACCOUNT_HEADER", tableName: "Settings")
		} footer: {
			Text("ADD_SELFHOSTED_ACCOUNT_FOOTER", tableName: "Settings")
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
