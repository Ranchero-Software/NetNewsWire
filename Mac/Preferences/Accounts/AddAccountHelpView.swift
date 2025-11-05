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

	var hasiCloudAccount: Bool {
		AccountManager.shared.accounts.contains(where: { $0.type == .cloudKit })
	}

	var body: some View {
		VStack {
			HStack {
				ForEach(accountTypes, id: \.self) { accountType in
					if accountType == .cloudKit && hasiCloudAccount {
						EmptyView()
					}
					else if !(AppDefaults.shared.isDeveloperBuild && accountType.isDeveloperRestricted) {
						Button(action: {
							delegate?.presentSheetForAccount(accountType)
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
	}
}
