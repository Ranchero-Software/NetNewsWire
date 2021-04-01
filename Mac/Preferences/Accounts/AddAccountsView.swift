//
//  AddAccountsView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 28/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore

enum AddAccountSections: Int, CaseIterable {
	case local = 0
	case icloud
	case web
	case selfhosted
	case allOrdered
	
	var sectionHeader: String {
		switch self {
		case .local:
			return NSLocalizedString("Local", comment: "Local Account")
		case .icloud:
			return NSLocalizedString("iCloud", comment: "iCloud Account")
		case .web:
			return NSLocalizedString("Web", comment: "Web Account")
		case .selfhosted:
			return NSLocalizedString("Self-hosted", comment: "Self hosted Account")
		case .allOrdered:
			return ""
		}
	}
	
	var sectionFooter: String {
		switch self {
		case .local:
			return NSLocalizedString("Local accounts do not sync subscriptions across devices.", comment: "Local Account")
		case .icloud:
			return NSLocalizedString("Use your iCloud account to sync your subscriptions across your iOS and macOS devices.", comment: "iCloud Account")
		case .web:
			return NSLocalizedString("Web accounts sync your subscriptions across all your devices.", comment: "Web Account")
		case .selfhosted:
			return NSLocalizedString("Self-hosted accounts sync your subscriptions across all your devices.", comment: "Self hosted Account")
		case .allOrdered:
			return ""
		}
	}
	
	var sectionContent: [AccountType] {
		switch self {
		case .local:
			return [.onMyMac]
		case .icloud:
			return [.cloudKit]
		case .web:
			if AppDefaults.shared.isDeveloperBuild {
				return [.bazQux, .feedbin, .feedly, .inoreader, .newsBlur, .theOldReader].filter({ $0.isDeveloperRestricted == false })
			} else {
				return [.bazQux, .feedbin, .feedly, .inoreader, .newsBlur, .theOldReader]
			}
		case .selfhosted:
			return [.freshRSS]
		case .allOrdered:
			return AddAccountSections.local.sectionContent +
			AddAccountSections.icloud.sectionContent +
				AddAccountSections.web.sectionContent +
				AddAccountSections.selfhosted.sectionContent
		}
	}
	
	
	
	
}

struct AddAccountsView: View {
    
	weak var parent: NSHostingController<AddAccountsView>? // required because presentationMode.dismiss() doesn't work
	var addAccountDelegate: AccountsPreferencesAddAccountDelegate?
	private let chunkLimit = 4 // use this to control number of accounts in each web account column
	@State private var selectedAccount: AccountType = .onMyMac
	
	init(delegate: AccountsPreferencesAddAccountDelegate?) {
		self.addAccountDelegate = delegate
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Choose an account type to add...")
				.font(.headline)
				.padding()
			
			localAccount
			
			if !AppDefaults.shared.isDeveloperBuild {
				icloudAccount
			}
			
			webAccounts
			selfhostedAccounts
			
			HStack(spacing: 12) {
				Spacer()
				if #available(OSX 11.0, *) {
					Button(action: {
						parent?.dismiss(nil)
					}, label: {
						Text("Cancel")
							.frame(width: 76)
					})
					.help("Cancel")
					.keyboardShortcut(.cancelAction)
					
				} else {
					Button(action: {
						parent?.dismiss(nil)
					}, label: {
						Text("Cancel")
							.frame(width: 76)
					})
					.accessibility(label: Text("Add Account"))
				}
				if #available(OSX 11.0, *) {
					Button(action: {
						addAccountDelegate?.presentSheetForAccount(selectedAccount)
						parent?.dismiss(nil)
					}, label: {
						Text("Continue")
							.frame(width: 76)
					})
					.help("Add Account")
					.keyboardShortcut(.defaultAction)
					
				} else {
					Button(action: {
						addAccountDelegate?.presentSheetForAccount(selectedAccount)
						parent?.dismiss(nil)
					}, label: {
						Text("Continue")
							.frame(width: 76)
					})
				}
			}
			.padding(.top, 12)
			.padding(.bottom, 4)
		}
		.pickerStyle(RadioGroupPickerStyle())
		.fixedSize(horizontal: false, vertical: true)
		.frame(width: 420)
		.padding()
    }
	
	var localAccount: some View {
		VStack(alignment: .leading) {
			Text("Local")
				.font(.headline)
				.padding(.horizontal)
			
			Picker(selection: $selectedAccount, label: Text(""), content: {
				ForEach(AddAccountSections.local.sectionContent, id: \.self, content: { account in
					HStack(alignment: .center) {
						account.image()
							.resizable()
							.aspectRatio(contentMode: .fit)
							.frame(width: 20, height: 20, alignment: .center)
							.padding(.leading, 4)
						Text(account.localizedAccountName())
					}
					.tag(account)
				})
			})
			.pickerStyle(RadioGroupPickerStyle())
			.offset(x: 7.5, y: 0)
			
			Text(AddAccountSections.local.sectionFooter).foregroundColor(.gray)
				.padding(.horizontal)
				.lineLimit(3)
				.fixedSize(horizontal: false, vertical: true)
			
		}
		
	}
	
	var icloudAccount: some View {
		VStack(alignment: .leading) {
			Text("iCloud")
				.font(.headline)
				.padding(.horizontal)
				.padding(.top, 8)
			
			Picker(selection: $selectedAccount, label: Text(""), content: {
				ForEach(AddAccountSections.icloud.sectionContent, id: \.self, content: { account in
					HStack(alignment: .center) {
						account.image()
							.resizable()
							.aspectRatio(contentMode: .fit)
							.frame(width: 20, height: 20, alignment: .center)
							.padding(.leading, 4)
						
						Text(account.localizedAccountName())
					}
					.tag(account)
				})
			})
			.offset(x: 7.5, y: 0)
			.disabled(isCloudInUse())
			
			Text(AddAccountSections.icloud.sectionFooter).foregroundColor(.gray)
				.padding(.horizontal)
				.lineLimit(3)
				.fixedSize(horizontal: false, vertical: true)
		}
	}
	
	@ViewBuilder
	var webAccounts: some View {
		VStack(alignment: .leading) {
			Text("Web")
				.font(.headline)
				.padding(.horizontal)
				.padding(.top, 8)
			
			HStack {
				ForEach(0..<chunkedWebAccounts().count, content: { chunk in
					VStack {
						Picker(selection: $selectedAccount, label: Text(""), content: {
							ForEach(chunkedWebAccounts()[chunk], id: \.self, content: { account in
		
								HStack(alignment: .center) {
									account.image()
										.resizable()
										.aspectRatio(contentMode: .fit)
										.frame(width: 20, height: 20, alignment: .center)
										.padding(.leading, 4)
									Text(account.localizedAccountName())
								}
								.tag(account)
								
							})
						})
						Spacer()
					}
				})
			}
			.offset(x: 7.5, y: 0)
			
			Text(AddAccountSections.web.sectionFooter).foregroundColor(.gray)
				.padding(.horizontal)
				.lineLimit(3)
				.fixedSize(horizontal: false, vertical: true)
		}
	}
	
	var selfhostedAccounts: some View {
		VStack(alignment: .leading) {
			Text("Self-hosted")
				.font(.headline)
				.padding(.horizontal)
				.padding(.top, 8)
			
			Picker(selection: $selectedAccount, label: Text(""), content: {
				ForEach(AddAccountSections.selfhosted.sectionContent, id: \.self, content: { account in
					HStack(alignment: .center) {
						account.image()
							.resizable()
							.aspectRatio(contentMode: .fit)
							.frame(width: 20, height: 20, alignment: .center)
							.padding(.leading, 4)
			
						Text(account.localizedAccountName())
					}.tag(account)
				})
			})
			.offset(x: 7.5, y: 0)
			
			Text(AddAccountSections.selfhosted.sectionFooter).foregroundColor(.gray)
				.padding(.horizontal)
				.lineLimit(3)
				.fixedSize(horizontal: false, vertical: true)
		}
	}
	
	private func isCloudInUse() -> Bool {
		AccountManager.shared.accounts.contains(where: { $0.type == .cloudKit })
	}
	
	private func chunkedWebAccounts() -> [[AccountType]] {
		AddAccountSections.web.sectionContent.chunked(into: chunkLimit)
	}

}


struct AddAccountsView_Previews: PreviewProvider {
	static var previews: some View {
		AddAccountsView(delegate: nil)
	}
}

