//
//  AddWebFeedView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 3/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore


struct AddWebFeedView: View {
	
	@Environment(\.presentationMode) private var presentationMode
	@StateObject private var viewModel = AddWebFeedModel()
	
    @ViewBuilder var body: some View {
		#if os(iOS)
			iosForm
				.onAppear {
					viewModel.pasteUrlFromPasteboard()
				}
				.onReceive(viewModel.$shouldDismiss, perform: { dismiss in
					if dismiss == true {
						presentationMode.wrappedValue.dismiss()
					}
				})
		#else
			macForm
				.onAppear {
					viewModel.pasteUrlFromPasteboard()
				}.alert(isPresented: $viewModel.showError) {
					Alert(title: Text("Oops"),
						  message: Text(viewModel.addFeedError!.localizedDescription),
						  dismissButton: Alert.Button.cancel({
							viewModel.addFeedError = AddWebFeedError.none
					}))
				}.onReceive(viewModel.$shouldDismiss, perform: { dismiss in
					if dismiss == true {
						presentationMode.wrappedValue.dismiss()
					}
				})
		#endif
    }
	
	#if os(macOS)
	var macForm: some View {
		Form {
			HStack {
				Spacer()
				Image(rsImage: AppAssets.faviconTemplateImage)
					.resizable()
					.renderingMode(.template)
					.frame(width: 30, height: 30)
				Text("Add a Web Feed")
					.font(.title)
				Spacer()
			}.padding()
			
			LazyVGrid(columns: [GridItem(.fixed(75), spacing: 10, alignment: .trailing),GridItem(.fixed(400), spacing: 0, alignment: .leading) ], alignment: .leading, spacing: 10, pinnedViews: [], content:{
				Text("URL:").bold()
				urlTextField
					.textFieldStyle(RoundedBorderTextFieldStyle())
					.help("The URL of the feed you want to add.")
				Text("Name:").bold()
				providedNameTextField
					.textFieldStyle(RoundedBorderTextFieldStyle())
					.help("The name of the feed. (Optional.)")
				Text("Folder:").bold()
				folderPicker
					.help("Pick the folder you want to add the feed to.")
			})
			buttonStack
		}
		.frame(maxWidth: 485)
		.padding(12)
	}
	#endif
	
	#if os(iOS)
	@ViewBuilder var iosForm: some View {
		NavigationView {
			List {
				urlTextField
				providedNameTextField
				folderPicker
			}
			.listStyle(InsetGroupedListStyle())
			.navigationBarTitle("Add Web Feed")
			.navigationBarTitleDisplayMode(.inline)
			.navigationBarItems(leading:
				Button("Cancel", action: {
					presentationMode.wrappedValue.dismiss()
				})
				.help("Cancel Add Feed")
				, trailing:
					HStack(spacing: 12) {
						if viewModel.showProgressIndicator == true {
							ProgressView()
						}
						Button("Add", action: {
							viewModel.addWebFeed()
						})
						.disabled(!viewModel.providedURL.mayBeURL)
						.help("Add Feed")
					}
				)
		}
	}
	#endif
	
	@ViewBuilder var urlTextField: some View {
		#if os(iOS)
		TextField("URL", text: $viewModel.providedURL)
			.disableAutocorrection(true)
			.autocapitalization(UITextAutocapitalizationType.none)
		#else
		TextField("URL", text: $viewModel.providedURL)
			.disableAutocorrection(true)
		#endif
	}
	
	var providedNameTextField: some View {
		TextField("Title (Optional)", text: $viewModel.providedName)
	}
	
	@ViewBuilder var folderPicker: some View {
		#if os(iOS)
		Picker("Folder", selection: $viewModel.selectedFolderIndex, content: {
			ForEach(0..<viewModel.containers.count, id: \.self, content: { index in
				if let containerName = (viewModel.containers[index] as? DisplayNameProvider)?.nameForDisplay {
					if viewModel.containers[index] is Folder {
						HStack(alignment: .top) {
							if let image = viewModel.smallIconImage(for: viewModel.containers[index]) {
								Image(rsImage: image)
									.foregroundColor(Color("AccentColor"))
							}
							Text("\(containerName)")
								.tag(index)
						}.padding(.leading, 16)
					} else {
						HStack(alignment: .top) {
							if let image = viewModel.smallIconImage(for: viewModel.containers[index]) {
								Image(rsImage: image)
									.foregroundColor(Color("AccentColor"))
							}
							Text(containerName)
								.tag(index)
						}
					}
				}
			})
		})
		#else
		Picker("", selection: $viewModel.selectedFolderIndex, content: {
			ForEach(0..<viewModel.containers.count, id: \.self, content: { index in
				if let containerName = (viewModel.containers[index] as? DisplayNameProvider)?.nameForDisplay {
					if viewModel.containers[index] is Folder {
						HStack {
							if let image = viewModel.smallIconImage(for: viewModel.containers[index]) {
								Image(rsImage: image)
							}
							Text("\(containerName)")
						}
						.padding(.leading, 2)
						.tag(index)
					} else {
						Text(containerName)
							.padding(.leading, 2)
							.tag(index)
					}
				}
			})
		})
		.padding(.leading, -8)
		#endif
		
	}
	
	var buttonStack: some View {
		HStack {
			if viewModel.showProgressIndicator == true {
				ProgressView()
					.frame(width: 25, height: 25)
					.help("Adding Feed")
			}
			Spacer()
			Button("Cancel", action: {
				presentationMode.wrappedValue.dismiss()
			})
			.help("Cancel Add Feed")
			
			Button("Add", action: {
				viewModel.addWebFeed()
			})
			.disabled(!viewModel.providedURL.mayBeURL)
			.help("Add Feed")
		}
		.padding(.trailing, 2)
	}
	
	
	
}

struct AddFeedView_Previews: PreviewProvider {
    static var previews: some View {
        AddWebFeedView()
    }
}
