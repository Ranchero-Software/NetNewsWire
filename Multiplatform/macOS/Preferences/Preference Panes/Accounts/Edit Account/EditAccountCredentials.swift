//
//  EditAccountCredentials.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 14/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Secrets

struct EditAccountCredentials: View {
	
	@ObservedObject var viewModel: AccountsPreferencesModel
	@Environment(\.presentationMode) var presentationMode
	
	@State private var userName: String = ""
	@State private var password: String = ""
	@State private var apiUrl: String?
	
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
				}.frame(width: 75)
				
				VStack(alignment: .leading, spacing: 12) {
					TextField("Username", text: $userName)
					SecureField("Password", text: $password)
				}
			}.textFieldStyle(RoundedBorderTextFieldStyle())
			
			Spacer()
			HStack{
				Spacer()
				Button("Dismiss", action: {
					presentationMode.wrappedValue.dismiss()
				})
				Button("Update", action: {
					presentationMode.wrappedValue.dismiss()
				})
			}
		}.onAppear {
			let credentials = try? viewModel.account?.retrieveCredentials(type: .basic)
			userName = credentials?.username ?? ""
			password = credentials?.secret ?? ""
		}
		.frame(idealWidth: 300, idealHeight: 200, alignment: .top)
		.padding()
    }
}

struct EditAccountCredentials_Previews: PreviewProvider {
    static var previews: some View {
		EditAccountCredentials(viewModel: AccountsPreferencesModel())
    }
}

