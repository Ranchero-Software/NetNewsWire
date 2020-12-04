//
//  AddReaderAPIAccountView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 03/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct AddReaderAPIAccountView: View {
	
	@Environment (\.presentationMode) var presentationMode
	@State private var username: String = ""
	@State private var password: String = ""
	public var accountType: AccountType
	
    var body: some View {
		VStack {
			HStack(spacing: 16) {
				VStack(alignment: .leading) {
					accountType.image()
						.resizable()
						.frame(width: 50, height: 50)
					Spacer()
				}
				VStack(alignment: .leading, spacing: 8) {
					Text("Sign in to your \(accountType.localizedAccountName()) account.")
						.font(.headline)
					HStack {
						if accountType == .freshRSS {
							Text("Don't have a \(accountType.localizedAccountName()) instance?")
								.font(.callout)
						} else {
							Text("Don't have an \(accountType.localizedAccountName()) account?")
								.font(.callout)
						}
						
						
						Button(action: {
							signUp()
						}, label: {
							Text(accountType == .freshRSS ? "Find out more." : "Sign up here.").font(.callout)
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
						ProgressView().scaleEffect(CGSize(width: 0.5, height: 0.5))
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
		.frame(width: 400, height: 230)
		.textFieldStyle(RoundedBorderTextFieldStyle())
    }
	
	
	private func signUp() {
		switch accountType {
		case .freshRSS:
			NSWorkspace.shared.open(URL(string: "https://freshrss.org")!)
		case .inoreader:
			NSWorkspace.shared.open(URL(string: "https://www.inoreader.com")!)
		case .bazQux:
			NSWorkspace.shared.open(URL(string: "https://bazqux.com")!)
		case .theOldReader:
			NSWorkspace.shared.open(URL(string: "https://theoldreader.com")!)
		default:
			return
		}
	}
	
}

struct AddReaderAPIAccountView_Previews: PreviewProvider {
    static var previews: some View {
		AddReaderAPIAccountView(accountType: .freshRSS)
    }
}
