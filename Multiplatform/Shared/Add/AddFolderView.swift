//
//  AddFolderView.swift
//  NetNewsWire
//
//  Created by Alex Faber on 04/07/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore

struct AddFolderView: View {
	
	@Environment(\.presentationMode) private var presentationMode
	@ObservedObject private var viewModel = AddFolderModel()
	
    @ViewBuilder var body: some View {
		#if os(iOS)
			iosForm
				.onReceive(viewModel.$shouldDismiss, perform: {
					dismiss in
					if dismiss == true {
						presentationMode
							.wrappedValue
							.dismiss()
					}
				})
		#else
			macForm
				.onReceive(viewModel.$shouldDismiss, perform: { dismiss in
					if dismiss == true {
						presentationMode.wrappedValue.dismiss()
					}
				})
		#endif
    }
	#if os(iOS)
	@ViewBuilder var iosForm: some View {
		NavigationView {
			Form {
				Section {
					TextField("Name", text: $viewModel.folderName)
				}
				Section {
					accountPicker
				}
			}
			.navigationTitle("Add Folder")
			.navigationBarTitleDisplayMode(.inline)
			.navigationBarItems(
				leading:Button("Cancel", action: {
					presentationMode.wrappedValue.dismiss()					
				}
				)
				.help("Cancel Adding Folder"),
				trailing:Button("Add", action: {
					viewModel.addFolder()
				}
				)
				.disabled(viewModel.folderName.isEmpty)
				.help("Save Adding Folder")
			)

		}
	}
	#endif
	
	#if os(macOS)
	@ViewBuilder var macForm: some View {
		Form {
			HStack {
				Spacer()
				Image(rsImage: AppAssets.faviconTemplateImage)
					.resizable()
					.renderingMode(.template)
					.frame(width: 30, height: 30)
				Text("Add a Folder")
					.font(.title)
				Spacer()
			}
			
			LazyVGrid(columns: [GridItem(.fixed(75), spacing: 10, alignment: .trailing),GridItem(.fixed(400), spacing: 0, alignment: .leading) ], alignment: .leading, spacing: 10, pinnedViews: [], content:{
				Text("Name:").bold()
				TextField("Name", text: $viewModel.folderName)
					.textFieldStyle(RoundedBorderTextFieldStyle())
					.help("The name of the folder you want to create")
				Text("Account:").bold()
				accountPicker
					.help("Pick the account you want to create a folder in.")
			})
			buttonStack
		}
		.frame(maxWidth: 485)
		.padding(12)
	}
	#endif
	
	var accountPicker: some View {
		Picker("Account:", selection: $viewModel.selectedAccountIndex, content: {
			ForEach(0..<viewModel.accounts.count, id: \.self, content: { index in
					Text("\(viewModel.accounts[index].account?.nameForDisplay ?? "")").tag(index)
			})
		})
	}
	
	var buttonStack: some View {
		HStack {
			if viewModel.showProgressIndicator == true {
				ProgressView()
					.frame(width: 25, height: 25)
					.help("Adding Folder")
			}
			Spacer()
			Button("Cancel", action: {
				presentationMode.wrappedValue.dismiss()
			})
			.help("Cancel Adding Folder")
			
			Button("Add", action: {
				viewModel.addFolder()
			})
			.disabled(viewModel.folderName.isEmpty)
			.help("Add Folder")
		}
	}
}

struct AddFolderView_Previews: PreviewProvider {
    static var previews: some View {
        AddFolderView()
    }
}
