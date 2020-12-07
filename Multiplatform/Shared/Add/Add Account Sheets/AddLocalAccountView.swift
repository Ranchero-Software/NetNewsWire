//
//  AddLocalAccountView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 02/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore

struct AddLocalAccountView: View {
	
	@State private var newAccountName: String = ""
	@Environment (\.presentationMode) var presentationMode
	
	var body: some View {
		#if os(macOS)
		macBody
		#else
		NavigationView {
			iosBody
		}
		#endif
	}
	
	#if os(iOS)
	var iosBody: some View {
		List {
			Section(header: formHeader, content: {
				TextField("Account Name", text: $newAccountName)
			})
			
			Section(footer: formFooter, content: {
				Button(action: {
					let newAccount = AccountManager.shared.createAccount(type: .onMyMac)
					newAccount.name = newAccountName
					presentationMode.wrappedValue.dismiss()
				}, label: {
					HStack {
						Spacer()
						Text("Add Account")
						Spacer()
					}
				})
			})
		}.navigationBarItems(leading:
			Button(action: {
				presentationMode.wrappedValue.dismiss()
			}, label: {
				Text("Cancel")
			})
		)
		.navigationBarTitleDisplayMode(.inline)
		.navigationTitle(Text(AccountType.onMyMac.localizedAccountName()))
		.listStyle(InsetGroupedListStyle())
	}
	#endif
	
	#if os(macOS)
	var macBody: some View {
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
						Button(action: {
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Cancel")
								.frame(width: 60)
						}).keyboardShortcut(.cancelAction)
						
						Button(action: {
							let newAccount = AccountManager.shared.createAccount(type: .onMyMac)
							newAccount.name = newAccountName
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Create")
								.frame(width: 60)
						}).keyboardShortcut(.defaultAction)
					}
				}
			}
		}
		.padding()
		.frame(minWidth: 400, maxWidth: 400, minHeight: 230, maxHeight: 260)
		.textFieldStyle(RoundedBorderTextFieldStyle())
	}
	#endif
	
	var formHeader: some View {
		HStack {
			Spacer()
			VStack(alignment: .center) {
				AccountType.onMyMac.image()
					.resizable()
					.frame(width: 50, height: 50)
			}
			Spacer()
		}.padding(.vertical)
	}
	
	var formFooter: some View {
		HStack {
			Spacer()
			VStack(spacing: 8) {
				Text("Local accounts do not sync your subscriptions across devices.").foregroundColor(.secondary)
			}
			.multilineTextAlignment(.center)
			.font(.caption)
			Spacer()
			
		}.padding(.vertical)
	}
	
}

struct AddLocalAccount_Previews: PreviewProvider {
	static var previews: some View {
		AddLocalAccountView()
	}
}
