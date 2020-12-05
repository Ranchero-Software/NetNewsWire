//
//  AddCloudKitAccountView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 03/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct AddCloudKitAccountView: View {
	
	@Environment (\.presentationMode) var presentationMode
	
    var body: some View {
		
		#if os(macOS)
		macBody
		#else
		iosBody
		#endif
		
    }
	
	#if os(iOS)
	var iosBody: some View {
		List {
			Section(header: formHeader, content: {
				Button(action: {
					_ = AccountManager.shared.createAccount(type: .cloudKit)
					presentationMode.wrappedValue.dismiss()
				}, label: {
					Text("Add")
				})
			})
		}.navigationBarItems(leading:
			Button(action: {
				presentationMode.wrappedValue.dismiss()
			}, label: {
				Text("Dismiss")
			})
		 
		 , trailing:
			Button(action: {
				_ = AccountManager.shared.createAccount(type: .cloudKit)
				presentationMode.wrappedValue.dismiss()
			}, label: {
				Text("Add")
			})
		)
	}
	#endif
	
	#if os(macOS)
	var macBody: some View {
		VStack {
			HStack(spacing: 16) {
				VStack(alignment: .leading) {
					AccountType.cloudKit.image()
						.resizable()
						.frame(width: 50, height: 50)
					Spacer()
				}
				VStack(alignment: .leading, spacing: 8) {
					Text("Sign in to your iCloud account.")
						.font(.headline)
					
					Text("This account syncs across your Mac and iOS devices using your iCloud account.")
						.foregroundColor(.secondary)
						.font(.callout)
						.lineLimit(2)
						.padding(.top, 4)
					
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
							_ = AccountManager.shared.createAccount(type: .cloudKit)
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Create")
								.frame(width: 60)
						})
						.keyboardShortcut(.defaultAction)
						.disabled(AccountManager.shared.activeAccounts.filter({ $0.type == .cloudKit }).count > 0)
					}
				}
			}
		}
		.padding()
		.frame(minWidth: 400, maxWidth: 400, maxHeight: 150)
	}
	#endif
	
	var formHeader: some View {
		HStack {
			VStack(alignment: .center) {
				AccountType.cloudKit.image()
					.resizable()
					.frame(width: 50, height: 50)
			Text("Sign in to your iCloud account.")
				.font(.headline)
			
			Text("This account syncs across your Mac and iOS devices using your iCloud account.")
				.foregroundColor(.secondary)
				.font(.callout)
				.lineLimit(2)
				.padding(.top, 4)
			}
		}
	}
}

struct AddCloudKitAccountView_Previews: PreviewProvider {
    static var previews: some View {
        AddCloudKitAccountView()
    }
}
