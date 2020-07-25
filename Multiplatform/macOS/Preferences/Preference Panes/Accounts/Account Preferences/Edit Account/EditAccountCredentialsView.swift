//
//  EditAccountCredentialsView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 14/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Secrets

struct EditAccountCredentialsView: View {
	
	@Environment(\.presentationMode) var presentationMode
	@StateObject private var editModel = EditAccountCredentialsModel()
	@ObservedObject var viewModel: AccountsPreferencesModel
	
    var body: some View {
		Form {
			HStack {
				Spacer()
				Image(rsImage: viewModel.account!.smallIcon!.image)
					.resizable()
					.frame(width: 30, height: 30)
				Text(viewModel.account?.nameForDisplay ?? "")
				Spacer()
			}.padding()
			
			HStack(alignment: .center) {
				VStack(alignment: .trailing, spacing: 12) {
					Text("Username: ")
					Text("Password: ")
					if viewModel.account?.type == .freshRSS {
						Text("API URL: ")
					}
				}.frame(width: 75)
				
				VStack(alignment: .leading, spacing: 12) {
					TextField("Username", text: $editModel.userName)
					SecureField("Password", text: $editModel.password)
					if viewModel.account?.type == .freshRSS {
						TextField("API URL", text: $editModel.apiUrl)
					}
				}
			}.textFieldStyle(RoundedBorderTextFieldStyle())
			
			Spacer()
			HStack{
				if editModel.accountIsUpdatingCredentials {
					ProgressView("Updating")
				}
				Spacer()
				Button("Cancel", action: {
					presentationMode.wrappedValue.dismiss()
				})
				if viewModel.account?.type != .freshRSS {
					Button("Update", action: {
						editModel.updateAccountCredentials(viewModel.account!)
					}).disabled(editModel.userName.count == 0 || editModel.password.count == 0)
				} else {
					Button("Update", action: {
						editModel.updateAccountCredentials(viewModel.account!)
					}).disabled(editModel.userName.count == 0 || editModel.password.count == 0 || editModel.apiUrl.count == 0)
				}
				
			}
		}.onAppear {
			editModel.retrieveCredentials(viewModel.account!)
		}
		.onChange(of: editModel.accountCredentialsWereUpdated) { value in
			if value == true {
				viewModel.sheetToShow = .none
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
    }
}

struct EditAccountCredentials_Previews: PreviewProvider {
    static var previews: some View {
		EditAccountCredentialsView(viewModel: AccountsPreferencesModel())
    }
}

