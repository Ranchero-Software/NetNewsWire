//
//  AddFeedlyAccountView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 05/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore
import RSWeb
import Secrets

struct AddFeedlyAccountView: View {
	
	@Environment (\.presentationMode) var presentationMode
	@StateObject private var model = AddFeedlyViewModel()
	
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
			Section(header: formHeader, footer: formFooter, content: {
				Button(action: {
					model.authenticateFeedly()
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
		.navigationTitle(Text(AccountType.feedly.localizedAccountName()))
		.listStyle(InsetGroupedListStyle())
		
	}
	#endif
	
	#if os(macOS)
	var macBody: some View {
		VStack {
			HStack(spacing: 16) {
				VStack(alignment: .leading) {
					AccountType.feedly.image()
						.resizable()
						.frame(width: 50, height: 50)
					Spacer()
				}
				VStack(alignment: .leading, spacing: 8) {
					Text("Sign in to your Feedly account.")
						.font(.headline)
					HStack {
						Text("Don't have a Feedly account?")
							.font(.callout)
						Button(action: {
							model.presentSignUpOption(.feedly)
						}, label: {
							Text("Sign up here.").font(.callout)
						}).buttonStyle(LinkButtonStyle())
					}
					
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
							model.authenticateFeedly()
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Sign In")
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
		.alert(isPresented: $model.showError, content: {
			Alert(title: Text("Sign In Error"), message: Text(model.accountUpdateError.description), dismissButton: .cancel())
		})
	}
	#endif

	var formHeader: some View {
		HStack {
			Spacer()
			VStack(alignment: .center) {
				AccountType.feedly.image()
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
				Text("Sign in to your Feedly account and sync your subscriptions across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon't have an Feedly account?").foregroundColor(.secondary)
				Button(action: {
					model.presentSignUpOption(.feedly)
				}, label: {
					Text("Sign Up Here").foregroundColor(.blue).multilineTextAlignment(.center)
				})
			}
			.multilineTextAlignment(.center)
			.font(.caption)
			Spacer()
			
		}.padding(.vertical)
	}
	
}

struct AddFeedlyAccountView_Previews: PreviewProvider {
    static var previews: some View {
        AddFeedlyAccountView()
    }
}
