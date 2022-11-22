//
//  AddMastodonUserView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 14/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import RSCore
import Account

struct AddMastodonUserView: View {
    
	// Model
	@StateObject private var addMastodonModel = AddMastodonViewModel()
	
	// Error handling
	@State private var showError: Bool = false
	@State private var error: Error?
	
	// Focus Management
	@FocusState private var userNameIsFocused: Bool
	@FocusState private var domainIsFocused: Bool
	@FocusState private var tagIsFocused: Bool
	
	// Environment
	@Environment(\.dismiss) var dismiss
	
	var body: some View {
		NavigationView {
			Form {
				Section(header: headerView) {}
				feedTypePicker
				if addMastodonModel.mastodonFeedType == .user {
					mastodonFollowUserDataEntry
				} else {
					mastodonFollowTagDataEntry
				}
				Section(footer: footerView) {}
			}
			.navigationTitle("Add Mastodon Feed")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button("Cancel") {
						dismiss()
					}
					.help("Dismiss the view.")
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					if addMastodonModel.showProgressIndicator {
						ProgressView()
					} else {
						Button {
							Task {
								do {
									try await addMastodonModel.addMastodonFeedToAccount()
									dismiss()
								} catch {
									self.error = error
									showError = true
								}
							}
						} label: {
							Text("Add")
								.bold()
						}
						.disabled(addMastodonModel.isMastodonDisabled())
						.help("Add the feed.")
					}
				}
			}
		}
    }
	
	var headerView: some View {
		VStack {
			HStack {
				Spacer()
				Image("mastodon.banner")
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 175)
				Spacer()
			}
		}
	}
	
	var footerView: some View {
		VStack(alignment: .center) {
			Text("Mastodon is free and open-source software for running self-hosted social networking services. It has microblogging features similar to the Twitter service, which are offered by a large number of independently run nodes, known as instances, each with its own code of conduct, terms of service, privacy options, and moderation policies.\n\n[Find out more](https://joinmastodon.org)")
				.multilineTextAlignment(.center)
		}
	}
	
	var feedTypePicker: some View {
		Picker("Follow", selection: $addMastodonModel.mastodonFeedType) {
			Text(MastodonFeedType.user.description)
				.tag(MastodonFeedType.user)
			Text(MastodonFeedType.tag.description)
				.tag(MastodonFeedType.tag)
		}
		.pickerStyle(.segmented)
		.listRowBackground(Color.clear)
		.help("Select the type of feed to add.")
	}
	
	var mastodonFollowUserDataEntry: some View {
		Group {
			Section(footer: Text("NetNewsWire")) {
				TextField("Username", text: $addMastodonModel.mastodonUserName, prompt: Text("Username"))
					.focused($userNameIsFocused)
					.autocorrectionDisabled(true)
					.textInputAutocapitalization(.never)
			}
			
			Section(footer: Text("micro.blog")) {
				TextField(text: $addMastodonModel.mastodonDomain, label: { Text("Mastodon Domain") })
					.autocorrectionDisabled(true)
					.textInputAutocapitalization(.never)
					.focused($domainIsFocused)
			}
			
			Section {
				folderPicker
			}
		}
		.alert("Error", isPresented: $showError) {
			Button("Dismiss", action: { self.showError = false })
		} message: {
			Text(error?.localizedDescription ?? "No error message")
		}
	}
	
	var mastodonFollowTagDataEntry: some View {
		Group {
			Section {
				TextField(text: $addMastodonModel.mastodonTag, label: { Text("#Tag") })
					.autocorrectionDisabled(true)
					.textInputAutocapitalization(.never)
					.focused($tagIsFocused)
			}
			
			Section {
				folderPicker
			}
		}
		.alert("Error", isPresented: $showError) {
			Button("Dismiss", action: { self.showError = false })
		} message: {
			Text(error?.localizedDescription ?? "No error message")
		}
	}
	
	var folderPicker: some View {
		Picker("Folder", selection: $addMastodonModel.selectedFolderIndex, content: {
			ForEach(0..<addMastodonModel.containers.count, id: \.self, content: { index in
				if let _ = (addMastodonModel.containers[index] as? DisplayNameProvider)?.nameForDisplay {
					nameForContainer(addMastodonModel.containers[index])
					.tag(index)
				}
			})
		})
		.foregroundColor(.secondary)
		.help("Select the account and folder to add the feed to.")
	}
	
	private func nameForContainer(_ container: Container) -> Text {
		if container is Folder {
			return Text(container.account!.nameForDisplay + " / " + (container as! DisplayNameProvider).nameForDisplay)
		} else {
			return Text((container as! DisplayNameProvider).nameForDisplay)
		}
	}
}

struct AddDerivedView_Previews: PreviewProvider {
    static var previews: some View {
		AddMastodonUserView()
    }
}
