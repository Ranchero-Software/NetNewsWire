//
//  AddAccountView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 28/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

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
			#if DEBUG
			return [.bazQux, .feedbin, .feedly, .feedWrangler, .inoreader, .newsBlur, .theOldReader]
			#else
			return [.bazQux, .feedbin, .feedly, .feedWrangler, .inoreader, .newsBlur, .theOldReader]
			#endif
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

struct AddAccountView: View {
	
	@State private var selectedAccount: AccountType = .onMyMac
	@Binding public var accountToAdd: AccountConfigurationSheets
	@Environment(\.presentationMode) var presentationMode
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Choose an account type to add...")
				.font(.headline)
				.padding()
			
			localAccount
			icloudAccount
			webAccounts
			selfhostedAccounts
			
			HStack(spacing: 12) {
				Spacer()
				if #available(OSX 11.0, *) {
					Button(action: {
						presentationMode.wrappedValue.dismiss()
					}, label: {
						Text("Cancel")
							.frame(width: 80)
					})
					.help("Cancel")
					.keyboardShortcut(.cancelAction)
					
				} else {
					Button(action: {
						presentationMode.wrappedValue.dismiss()
					}, label: {
						Text("Cancel")
							.frame(width: 80)
					})
					.accessibility(label: Text("Add Account"))
				}
				if #available(OSX 11.0, *) {
					Button(action: {
						presentationMode.wrappedValue.dismiss()
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
							accountToAdd = AccountConfigurationSheets.addSelectedAccount(selectedAccount)
						})
					}, label: {
						Text("Continue")
							.frame(width: 80)
					})
					.help("Add Account")
					.keyboardShortcut(.defaultAction)
					
				} else {
					Button(action: {
						accountToAdd = AccountConfigurationSheets.addSelectedAccount(selectedAccount)
						presentationMode.wrappedValue.dismiss()
						
					}, label: {
						Text("Continue")
							.frame(width: 80)
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
							.frame(width: 25, height: 25, alignment: .center)
							.padding(.leading, 4)
						Text(account.localizedAccountName())
					}
					.tag(account)
				})
			})
			.pickerStyle(RadioGroupPickerStyle())
			.offset(x: 7.5, y: 0)
			
			Text(AddAccountSections.local.sectionFooter).foregroundColor(.gray)
				.font(.caption)
				.padding(.horizontal)
			
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
							.frame(width: 25, height: 25, alignment: .center)
							.padding(.leading, 4)
						
						Text(account.localizedAccountName())
					}
					.tag(account)
				})
			})
			.offset(x: 7.5, y: 0)
			.disabled(isCloudInUse())
			
			Text(AddAccountSections.icloud.sectionFooter).foregroundColor(.gray)
				.font(.caption)
				.padding(.horizontal)
		}
	}
	
	var webAccounts: some View {
		VStack(alignment: .leading) {
			Text("Web")
				.font(.headline)
				.padding(.horizontal)
				.padding(.top, 8)
			
			Picker(selection: $selectedAccount, label: Text(""), content: {
				ForEach(AddAccountSections.web.sectionContent, id: \.self, content: { account in
					
					HStack(alignment: .center) {
						account.image()
							.resizable()
							.aspectRatio(contentMode: .fit)
							.frame(width: 25, height: 25, alignment: .center)
							.padding(.leading, 4)
							
						Text(account.localizedAccountName())
					}
					.tag(account)
					
				})
			})
			.offset(x: 7.5, y: 0)
			
			Text(AddAccountSections.web.sectionFooter).foregroundColor(.gray)
				.font(.caption)
				.padding(.horizontal)
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
							.frame(width: 25, height: 25, alignment: .center)
							.padding(.leading, 4)
			
						Text(account.localizedAccountName())
					}.tag(account)
				})
			})
			.offset(x: 7.5, y: 0)
			
			Text(AddAccountSections.selfhosted.sectionFooter).foregroundColor(.gray)
				.font(.caption)
				.padding(.horizontal)
		}
	}
	
	private func isCloudInUse() -> Bool {
		AccountManager.shared.accounts.contains(where: { $0.type == .cloudKit })
	}
	
	private func isRestricted(_ accountType: AccountType) -> Bool {
		if AppDefaults.shared.isDeveloperBuild && (accountType == .feedly || accountType == .feedWrangler || accountType == .inoreader) {
			return true
		}
		return false
	}
}


