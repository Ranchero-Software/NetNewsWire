//
//  AccountDetailView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 14/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import Combine

struct AccountDetailView: View {
    
	@ObservedObject var viewModel: AccountsPreferencesModel
	
	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 8, style: .circular)
				.foregroundColor(Color.secondary.opacity(0.1))
				.padding(.top, 8)
			
			VStack {
				editAccountHeader
				if viewModel.account != nil {
					editAccountForm
				}
				Spacer()
			}
		}
    }
	
	var editAccountHeader: some View {
		HStack {
			Spacer()
			Button("Account Information", action: {})
			Spacer()
		}
		.padding([.leading, .trailing, .bottom], 4)
	}
	
	var editAccountForm: some View {
		Form(content: {
			HStack(alignment: .top) {
				Text("Type: ")
					.frame(width: 50)
				VStack(alignment: .leading) {
					Text(viewModel.account!.defaultName)
					Toggle("Active", isOn: $viewModel.accountIsActive)
				}
			}
			HStack(alignment: .top) {
				Text("Name: ")
					.frame(width: 50)
				VStack(alignment: .leading) {
					TextField(viewModel.account!.name ?? "", text: $viewModel.accountName)
						.textFieldStyle(RoundedBorderTextFieldStyle())
					Text("The name appears in the sidebar. It can be anything you want. You can even use emoji. 🎸")
						.foregroundColor(.secondary)
				}
			}
			Spacer()
			if viewModel.account?.type != .onMyMac {
				HStack {
					Spacer()
					Button("Credentials", action: {
						viewModel.sheetToShow = .credentials
					})
					Spacer()
				}
			}
		})
		.padding()
		
	}
	
}

struct AccountDetailView_Previews: PreviewProvider {
    static var previews: some View {
		AccountDetailView(viewModel: AccountsPreferencesModel())
    }
}
