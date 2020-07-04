//
//  AddFolderModel.swift
//  NetNewsWire
//
//  Created by Alex Faber on 04/07/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import RSCore
import SwiftUI


class AddFolderModel: ObservableObject {
	
	@Published var shouldDismiss: Bool = false
	@Published var folderName: String = ""
	@Published var selectedAccountIndex: Int = 0
	@Published var accounts: [Account] = []

	@Published var showError: Bool = false
	@Published var showProgressIndicator: Bool = false
	
	init() {
		for account in
			AccountManager.shared.sortedActiveAccounts{
			accounts.append(account)
		}
	}
	
	func addFolder() {
		let account = accounts[selectedAccountIndex]
		
		showProgressIndicator = true

		account.addFolder(folderName){ result in
			self.showProgressIndicator = false

			switch result {
			case .success(_):
				self.shouldDismiss = true
				
			case .failure(let error):
				print("Error")
				print(error)
			}
			
		}
	}
}
