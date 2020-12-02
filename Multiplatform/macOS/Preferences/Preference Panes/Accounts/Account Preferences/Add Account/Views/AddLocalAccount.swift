//
//  AddLocalAccount.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 02/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore

struct AddLocalAccount: View {
	
	@State private var newAccountName: String = ""
	
    var body: some View {
		VStack {
			HStack(spacing: 16) {
				VStack(alignment: .leading) {
					AccountType.onMyMac.image()
						.resizable()
						.frame(width: 50, height: 50)
					Spacer()
				}
				VStack(alignment: .leading, spacing: 8) {
					Text("Create a local account on your Mac.")
						.font(.headline)
					Text("Local accounts store their data on your Mac. They do not sync across your devices.")
						.font(.callout)
						.foregroundColor(.secondary)
					HStack {
						Text("Name: ")
						TextField("Account Name", text: $newAccountName)
					}.padding(.top, 8)
					Spacer()
					HStack(spacing: 8) {
						Spacer()
						Button(action: {}, label: {
							Text("Cancel").frame(width: 60)
						}).keyboardShortcut(.cancelAction)
						
						Button(action: {}, label: {
							Text("Create").frame(width: 60)
						}).keyboardShortcut(.defaultAction)
					}
				}
			}
		}
		.padding()
		.frame(width: 384, height: 200)
    }
}

struct AddLocalAccount_Previews: PreviewProvider {
    static var previews: some View {
        AddLocalAccount()
    }
}
