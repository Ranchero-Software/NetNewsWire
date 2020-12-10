//
//  AddAccountHelpView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 4/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct AddAccountHelpView: View {
	
	let accountTypes: [AccountType] = AddAccountSections.allOrdered.sectionContent
	var delegate: AccountsPreferencesAddAccountDelegate?
	var helpText: String
	@State private var iCloudUnavailableError: Bool = false
	
	var body: some View {
		VStack {
			HStack {
				ForEach(accountTypes, id: \.self) { accountType in
					if !(AppDefaults.shared.isDeveloperBuild && accountType.isDeveloperRestricted) {
						Button(action: {
							if accountType == .cloudKit && AccountManager.shared.accounts.contains(where: { $0.type == .cloudKit }) {
								iCloudUnavailableError = true
							} else {
								delegate?.presentSheetForAccount(accountType)
							}
						}, label: {
							accountType.image()
								.resizable()
								.frame(width: 20, height: 20, alignment: .center)
						})
						.buttonStyle(PlainButtonStyle())
					}
				}
			}
			
			Text(helpText)
				.multilineTextAlignment(.center)
				.padding(.top, 8)
			
		}
		.alert(isPresented: $iCloudUnavailableError, content: {
			Alert(title: Text(NSLocalizedString("Error", comment: "Error")),
				  message: Text(NSLocalizedString("You've already set up an iCloud account.", comment: "Error")),
				  dismissButton: Alert.Button.cancel({
					iCloudUnavailableError = false
				  }))
		})
	}
	
}
