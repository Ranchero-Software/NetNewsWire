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
	@State private var hoveringId: String? = nil
	
	var body: some View {
		VStack {
			HStack {
				ForEach(accountTypes, id: \.self) { account in
					account.image()
						.resizable()
						.frame(width: 20, height: 20, alignment: .center)
						.onTapGesture {
							delegate?.presentSheetForAccount(account)
							hoveringId = nil
						}
						.onHover(perform: { hovering in
							if hovering {
								hoveringId = account.localizedAccountName()
							} else {
								hoveringId = nil
							}
						})
						.scaleEffect(hoveringId == account.localizedAccountName() ? 1.2 : 1)
						.shadow(radius: hoveringId == account.localizedAccountName() ? 0.8 : 0)
				}
			}
			
			Text(helpText)
				.multilineTextAlignment(.center)
				.padding(.top, 8)
				
		}
	}
}
