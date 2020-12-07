//
//  AddNewsBlurAccountView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 03/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore
import RSWeb
import Secrets

struct AddNewsBlurAccountView: View {
	
	@Environment (\.presentationMode) var presentationMode
	@StateObject private var model = AddNewsBlurViewModel()
	
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
					model.authenticateNewsBlur()
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
		.listStyle(InsetGroupedListStyle())
		.navigationBarTitleDisplayMode(.inline)
		.navigationTitle(Text("NewsBlur"))
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
					AccountType.newsBlur.image()
						.frame(width: 50, height: 50)
					Spacer()
				}
				VStack(alignment: .leading, spacing: 8) {
					Text("Sign in to your NewsBlur account.")
						.font(.headline)
					HStack {
						Text("Don't have a NewsBlur account?")
							.font(.callout)
						Button(action: {
							model.presentSignUpOption(.newsBlur)
						}, label: {
							Text("Sign up here.").font(.callout)
						}).buttonStyle(LinkButtonStyle())
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
							model.authenticateNewsBlur()
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
		.textFieldStyle(RoundedBorderTextFieldStyle())
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
				AccountType.newsBlur.image()
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
				Text("Sign in to your NewsBlur account and sync your subscriptions across your devices. Your username and password and password will be encrypted and stored in Keychain.").foregroundColor(.secondary)
				Text("Don't have a NewsBlur account?").foregroundColor(.secondary)
				Button(action: {
					model.presentSignUpOption(.newsBlur)
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

struct AddNewsBlurAccountView_Previews: PreviewProvider {
    static var previews: some View {
        AddNewsBlurAccountView()
    }
}
