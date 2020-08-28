//
//  SettingsView.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 30/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsView: View {
	
	@Environment(\.presentationMode) var presentationMode

	@StateObject private var viewModel = SettingsModel()
	@StateObject private var feedsSettingsModel = FeedsSettingsModel()
	@StateObject private var settings = AppDefaults.shared

	var body: some View {
		NavigationView {
			List {
				systemSettings
				accounts
				importExport
				timeline
				articles
				appearance
				help
			}
			.listStyle(InsetGroupedListStyle())
			.navigationBarTitle("Settings", displayMode: .inline)
			.navigationBarItems(leading:
				HStack {
					Button("Done") {
						presentationMode.wrappedValue.dismiss()
					}
				}
			)
		}
		.fileImporter(
			isPresented: $feedsSettingsModel.isImporting,
			allowedContentTypes: feedsSettingsModel.importingContentTypes,
			allowsMultipleSelection: true,
			onCompletion: { result in
				if let urls = try? result.get() {
					feedsSettingsModel.processImportedFiles(urls)
				}
			}
		)
		.fileMover(isPresented: $feedsSettingsModel.isExporting,
				   file: feedsSettingsModel.generateExportURL()) { _ in }
		.sheet(isPresented: $viewModel.presentSheet, content: {
			SafariView(url: viewModel.selectedWebsite.url!)
		})
	}
	
	var systemSettings: some View {
		Section(header: Text("Notifications, Badge, Data, & More"), content: {
			Button(action: {
				UIApplication.shared.open(URL(string: "\(UIApplication.openSettingsURLString)")!)
			}, label: {
				Text("Open System Settings").foregroundColor(.primary)
			})
		})
	}
	
	var accounts: some View {
		Section(header: Text("Accounts"), content: {
			ForEach(0..<viewModel.accounts.count, id: \.hashValue , content: { i in
				NavigationLink(
					destination: SettingsDetailAccountView(viewModel.accounts[i]),
					label: {
						Text(viewModel.accounts[i].nameForDisplay)
					})
			})
			NavigationLink(
				destination: SettingsAddAccountView(),
				label: {
					Text("Add Account")
				})
		})
	}
	
	var importExport: some View {
		Section(header: Text("Feeds"), content: {
			if viewModel.activeAccounts.count > 1 {
				NavigationLink("Import Subscriptions", destination: importOptions)
			}
			else {
				Button(action:{
					if feedsSettingsModel.checkForActiveAccount() {
						feedsSettingsModel.importOPML(account: viewModel.activeAccounts.first)
					}
				}) {
					Text("Import Subscriptions")
						.foregroundColor(.primary)
				}
			}

			if viewModel.accounts.count > 1 {
				NavigationLink("Export Subscriptions", destination: exportOptions)
			}
			else {
				Button(action:{
					feedsSettingsModel.exportOPML(account: viewModel.accounts.first)
				}) {
					Text("Export Subscriptions")
						.foregroundColor(.primary)
				}
			}
			Toggle("Confirm When Deleting", isOn: $settings.sidebarConfirmDelete)
				.toggleStyle(SwitchToggleStyle(tint: .accentColor))
		})
		.alert(isPresented: $feedsSettingsModel.showError) {
			Alert(
				title: Text(feedsSettingsModel.feedsSettingsError!.title ?? "Oops"),
				message: Text(feedsSettingsModel.feedsSettingsError!.localizedDescription),
				dismissButton: Alert.Button.cancel({
					feedsSettingsModel.feedsSettingsError = FeedsSettingsError.none
				}))
		}
	}

	var importOptions: some View {
		List {
			Section(header: Text("Choose an account to receive the imported feeds and folders"), content: {
				ForEach(0..<viewModel.activeAccounts.count, id: \.hashValue , content: { i in
					Button {
						feedsSettingsModel.importOPML(account: viewModel.activeAccounts[i])
					} label: {
						Text(viewModel.activeAccounts[i].nameForDisplay)
					}
				})
			})
		}
		.listStyle(InsetGroupedListStyle())
		.navigationBarTitle("Import Subscriptions", displayMode: .inline)
	}

	var exportOptions: some View {
		List {
			Section(header: Text("Choose an account with the subscriptions to export"), content: {
				ForEach(0..<viewModel.accounts.count, id: \.hashValue , content: { i in
					Button {
						feedsSettingsModel.exportOPML(account: viewModel.accounts[i])
					} label: {
						Text(viewModel.accounts[i].nameForDisplay)
					}
				})
				
			})
		}
		.listStyle(InsetGroupedListStyle())
		.navigationBarTitle("Export Subscriptions", displayMode: .inline)
	}
	
	
	
	var timeline: some View {
		Section(header: Text("Timeline"), content: {
			Toggle("Sort Oldest to Newest", isOn: $settings.timelineSortDirection)
			Toggle("Group by Feed", isOn: $settings.timelineGroupByFeed)
			Toggle("Refresh to Clear Read Articles", isOn: $settings.refreshClearsReadArticles)
			NavigationLink(
				destination: TimelineLayoutView().environmentObject(settings),
				label: {
					Text("Timeline Layout")
				})
		}).toggleStyle(SwitchToggleStyle(tint: .accentColor))
	}
	
	var articles: some View {
		Section(header: Text("Articles"), content: {
			Toggle("Confirm Mark All as Read", isOn: .constant(true))
			Toggle(isOn: .constant(true), label: {
				VStack(alignment: .leading, spacing: 4) {
					Text("Enable Full Screen Articles")
					Text("Tap the article top bar to enter Full Screen. Tap the bottom or top to exit.").font(.caption).foregroundColor(.secondary)
				}
			})
		}).toggleStyle(SwitchToggleStyle(tint: .accentColor))
	}
	
	var appearance: some View {
		Section(header: Text("Appearance"), content: {
			NavigationLink(
				destination: ColorPaletteContainerView().environmentObject(settings),
				label: {
					HStack {
						Text("Color Palette")
						Spacer()
						Text(settings.userInterfaceColorPalette.description)
							.foregroundColor(.secondary)
					}
				})
		})
	}
	
	var help: some View {
		Section(header: Text("Help"), footer: Text(appVersion()).font(.caption2), content: {
			Button("NetNewsWire Help", action: {
				viewModel.selectedWebsite = .netNewsWireHelp
			}).foregroundColor(.primary)
			Button("Website", action: {
				viewModel.selectedWebsite = .netNewsWire
			}).foregroundColor(.primary)
			Button("How To Support NetNewsWire", action: {
				viewModel.selectedWebsite = .supportNetNewsWire
			}).foregroundColor(.primary)
			Button("Github Repository", action: {
				viewModel.selectedWebsite = .github
			}).foregroundColor(.primary)
			Button("Bug Tracker", action: {
				viewModel.selectedWebsite = .bugTracker
			}).foregroundColor(.primary)
			Button("NetNewsWire Slack", action: {
				viewModel.selectedWebsite = .netNewsWireSlack
			}).foregroundColor(.primary)
			Button("Release Notes", action: {
				viewModel.selectedWebsite = .releaseNotes
			}).foregroundColor(.primary)
			NavigationLink(
				destination: SettingsAboutView(),
				label: {
					Text("About NetNewsWire")
				})
		})
		
	}
	
	private func appVersion() -> String {
		let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
		let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
		return "NetNewsWire \(version) (Build \(build))"
	}

}

struct SettingsView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsView()
	}
}
