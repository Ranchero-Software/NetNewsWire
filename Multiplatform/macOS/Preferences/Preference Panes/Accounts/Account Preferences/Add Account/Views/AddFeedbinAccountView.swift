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

struct AddFeedbinAccountView: View {
	
	@Environment (\.presentationMode) var presentationMode
	@State private var username: String = ""
	@State private var password: String = ""
 
	var body: some View {
		VStack {
			HStack(spacing: 16) {
				VStack(alignment: .leading) {
					AccountType.feedbin.image()
						.resizable()
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
							NSWorkspace.shared.open(URL(string: "https://feedbin.com/signup")!)
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
							TextField("me@email.com", text: $username)
							SecureField("•••••••••••", text: $password)
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
						Button(action: {
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Cancel")
								.frame(width: 60)
						}).keyboardShortcut(.cancelAction)

						Button(action: {
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Create")
								.frame(width: 60)
						})
						.keyboardShortcut(.defaultAction)
						.disabled(username.isEmpty && password.isEmpty)
					}
				}
			}
		}
		.padding()
		.frame(width: 384, height: 220)
		.textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

struct AddFeedbinAccountView_Previews: PreviewProvider {
    static var previews: some View {
        AddFeedbinAccountView()
    }
}
