//
//  AddFeedbinAccountView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 02/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore
import RSWeb
import Secrets

struct AddFeedbinAccountView: View {
	
	@Environment (\.presentationMode) var presentationMode
	@StateObject private var model = AddFeedbinViewModel()
 
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
				TextField("Email", text: $model.username)
				if model.showPassword == false {
					ZStack {
						HStack {
							SecureField("Password", text: $model.password)
							Spacer()
							Image(systemName: "eye.fill")
								.foregroundColor(.accentColor)
								.onTapGesture {
									model.showPassword = true
								}
						}
					}
				}
				else {
					ZStack {
						HStack {
							TextField("Password", text: $model.password)
							Spacer()
							Image(systemName: "eye.slash.fill")
								.foregroundColor(.accentColor)
								.onTapGesture {
									model.showPassword = false
								}
						}
					}
				}
				
			})
			
			Section(footer: formFooter, content: {
				Button(action: {
					model.authenticateFeedbin()
				}, label: {
					HStack {
						Spacer()
						Text("Add Account")
						Spacer()
					}
				}).disabled(model.username.isEmpty || model.password.isEmpty)
			})
			
		}
		.navigationBarItems(leading:
			Button(action: {
				presentationMode.wrappedValue.dismiss()
			}, label: {
				Text("Cancel")
			}))
		.listStyle(.inset)
		.navigationBarTitleDisplayMode(.inline)
		.navigationTitle(Text("Feedbin"))
		.alert(isPresented: $model.showError, content: {
			Alert(title: Text("Sign In Error"), message: Text(model.accountUpdateError.description), dismissButton: .cancel(Text("Dismiss")))
		})
		.onReceive(model.$canDismiss, perform: { value in
			if value == true {
				presentationMode.wrappedValue.dismiss()
			}
		})
	}
	#endif
	
	#if os(macOS)
	var macBody: some View {
		VStack {
			HStack(spacing: 16) {
				VStack(alignment: .leading) {
					AccountType.feedbin.image()
						.frame(width: 50, height: 50)
					Spacer()
				}
				VStack(alignment: .leading, spacing: 8) {
					Text("Sign in to your Feedbin account.")
						.font(.headline)
					HStack {
						Text("Don't have a Feedbin account?")
							.font(.callout)
						Button(action: {
							model.presentSignUpOption(.feedbin)
						}, label: {
							Text("Sign up here.").font(.callout)
						}).buttonStyle(.link)
					}
					
					HStack {
						VStack(alignment: .trailing, spacing: 14) {
							Text("Email")
							Text("Password")
						}
						VStack(spacing: 8) {
							TextField("me@email.com", text: $model.username)
							SecureField("•••••••••••", text: $model.password)
						}
					}
					
					Text("Your username and password will be encrypted and stored in Keychain.")
						.foregroundColor(.secondary)
						.font(.callout)
						.lineLimit(2)
						.padding(.top, 4)
					
					Spacer()
					HStack(spacing: 8) {
						Spacer()
						ProgressView()
							.scaleEffect(CGSize(width: 0.5, height: 0.5))
							.hidden(!model.isAuthenticating)
						Button(action: {
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Cancel")
								.frame(width: 60)
						}).keyboardShortcut(.cancelAction)

						Button(action: {
							model.authenticateFeedbin()
						}, label: {
							Text("Sign In")
								.frame(width: 60)
						})
						.keyboardShortcut(.defaultAction)
						.disabled(model.username.isEmpty || model.password.isEmpty)
					}
				}
			}
		}
		.padding()
		.frame(minWidth: 400, maxWidth: 400, minHeight: 230, maxHeight: 260)
		.textFieldStyle(.roundedBorder)
		.alert(isPresented: $model.showError, content: {
			Alert(title: Text("Sign In Error"), message: Text(model.accountUpdateError.description), dismissButton: .cancel())
		})
		.onReceive(model.$canDismiss, perform: { value in
			if value == true {
				presentationMode.wrappedValue.dismiss()
			}
		})
	}
	#endif
	
	var formHeader: some View {
		HStack {
			Spacer()
			VStack(alignment: .center) {
				AccountType.feedbin.image()
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
				Text("Sign in to your Feedbin account and sync your subscriptions across your devices. Your username and password and password will be encrypted and stored in Keychain.").foregroundColor(.secondary)
				Text("Don't have a Feedbin account?").foregroundColor(.secondary)
				Button(action: {
					model.presentSignUpOption(.feedbin)
				}, label: {
					Text("Sign Up Here").foregroundColor(.blue).multilineTextAlignment(.center)
				})
				ProgressView().hidden(!model.isAuthenticating)
			}
			.multilineTextAlignment(.center)
			.font(.caption2)
			Spacer()
			
		}.padding(.vertical)
	}
	
	
}

struct AddFeedbinAccountView_Previews: PreviewProvider {
    static var previews: some View {
        AddFeedbinAccountView()
    }
}
