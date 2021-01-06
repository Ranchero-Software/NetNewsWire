//
//  FixAccountCredentialView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 24/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct FixAccountCredentialView: View {
	
	let accountSyncError: AccountSyncError
	@Environment(\.presentationMode) var presentationMode
	@StateObject private var editModel = EditAccountCredentialsModel()
	
	
    var body: some View {
		#if os(macOS)
		MacForm
			.onAppear {
				editModel.retrieveCredentials(accountSyncError.account)
			}
			.onChange(of: editModel.accountCredentialsWereUpdated) { value in
				if value == true {
					presentationMode.wrappedValue.dismiss()
				}
			}
			.alert(isPresented: $editModel.showError) {
				Alert(title: Text("Error Adding Account"),
					  message: Text(editModel.error.description),
					  dismissButton: .default(Text("Dismiss"),
											  action: {
												editModel.error = .none
											  }))
			}
			.frame(idealWidth: 300, idealHeight: 200, alignment: .top)
			.padding()
		#else
		iOSForm
			.onAppear {
				editModel.retrieveCredentials(accountSyncError.account)
			}
			.onChange(of: editModel.accountCredentialsWereUpdated) { value in
				if value == true {
					presentationMode.wrappedValue.dismiss()
				}
			}
			.alert(isPresented: $editModel.showError) {
				Alert(title: Text("Error Adding Account"),
					  message: Text(editModel.error.description),
					  dismissButton: .default(Text("Dismiss"),
											  action: {
												editModel.error = .none
											  }))
			}
		#endif
		
		
    }
	
	var MacForm: some View {
		Form {
			header
			HStack(alignment: .center) {
				VStack(alignment: .trailing, spacing: 12) {
					Text("Username: ")
					Text("Password: ")
					if accountSyncError.account.type == .freshRSS {
						Text("API URL: ")
					}
				}.frame(width: 75)
				
				VStack(alignment: .leading, spacing: 12) {
					accountFields
				}
			}
			.textFieldStyle(RoundedBorderTextFieldStyle())
			
			Spacer()
			HStack{
				if editModel.accountIsUpdatingCredentials {
					ProgressView("Updating")
				}
				Spacer()
				cancelButton
				updateButton
			}
		}.frame(height: 220)
	}
	
	#if os(iOS)
	var iOSForm: some View {
		
		NavigationView {
			List {
				Section(header: header, content: {
					accountFields
				})
			}
			.listStyle(InsetGroupedListStyle())
			.navigationBarItems(
				leading:
					cancelButton
				, trailing:
					HStack {
						if editModel.accountIsUpdatingCredentials {
							ProgressView()
								.frame(width: 20 , height: 20)
								.padding(.horizontal, 4)
						}
						updateButton
					}
					
			)
		}
	}
	#endif
	
	var header: some View {
		HStack {
			Spacer()
			VStack {
				Image(rsImage: accountSyncError.account.smallIcon!.image)
					.resizable()
					.frame(width: 30, height: 30)
				Text(accountSyncError.account.nameForDisplay)
				Text(accountSyncError.error.localizedDescription)
					.multilineTextAlignment(.center)
					.lineLimit(3)
					.padding(.top, 4)
			}
			Spacer()
		}.padding()
	}
	
	@ViewBuilder
	var accountFields: some View {
		TextField("Username", text: $editModel.userName)
		SecureField("Password", text: $editModel.password)
		if accountSyncError.account.type == .freshRSS {
			TextField("API URL", text: $editModel.apiUrl)
		}
	}
	
	@ViewBuilder
	var updateButton: some View {
		if accountSyncError.account.type != .freshRSS {
			Button("Update", action: {
				editModel.updateAccountCredentials(accountSyncError.account)
			}).disabled(editModel.userName.count == 0 || editModel.password.count == 0)
		} else {
			Button("Update", action: {
				editModel.updateAccountCredentials(accountSyncError.account)
			}).disabled(editModel.userName.count == 0 || editModel.password.count == 0 || editModel.apiUrl.count == 0)
		}
	}
	
	var cancelButton: some View {
		Button("Cancel", action: {
			presentationMode.wrappedValue.dismiss()
		})
	}
	
}

