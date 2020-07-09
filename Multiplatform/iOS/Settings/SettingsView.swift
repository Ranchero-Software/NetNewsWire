//
//  SettingsView.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 30/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import UniformTypeIdentifiers

struct SettingsView: View {
	
	@Environment(\.presentationMode) var presentationMode
	@Environment(\.exportFiles) var exportAction
	@Environment(\.importFiles) var importAction

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
			Button(action:{
				feedsSettingsModel.onTapImportOPML(action: importOPML)
			}) {
				Text("Import Subscriptions")
					.actionSheet(isPresented: $feedsSettingsModel.showingImportActionSheet, content: importActionSheet)
					.foregroundColor(.primary)
			}
			Button(action:{
				feedsSettingsModel.onTapExportOPML(action: exportOPML)
			}) {
				Text("Export Subscriptions")
					.actionSheet(isPresented: $feedsSettingsModel.showingExportActionSheet, content: exportActionSheet)
					.foregroundColor(.primary)
			}
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

	private func importActionSheet() -> ActionSheet {
		var buttons = viewModel.accounts.map { (account) -> ActionSheet.Button in
			ActionSheet.Button.default(Text(account.nameForDisplay)) {
				importOPML(account: account)
			}
		}
		buttons.append(.cancel())
		return ActionSheet(
			title: Text("Choose an account to receive the imported feeds and folders"),
			buttons: buttons
		)
	}

	private func exportActionSheet() -> ActionSheet {
		var buttons = viewModel.accounts.map { (account) -> ActionSheet.Button in
			ActionSheet.Button.default(Text(account.nameForDisplay)) {
				exportOPML(account: account)
			}
		}
		buttons.append(.cancel())
		return ActionSheet(
			title: Text("Choose an account with the subscriptions to export"),
			buttons: buttons
		)
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
			NavigationLink(
				destination: SettingsAboutView(),
				label: {
					Text("About NetNewsWire")
				})
		})
		
	}
	
	private func appVersion() -> String {
		let dict = NSDictionary(contentsOf: Bundle.main.url(forResource: "Info", withExtension: "plist")!)
		let version = dict?.object(forKey: "CFBundleShortVersionString") as? String ?? ""
		let build = dict?.object(forKey: "CFBundleVersion") as? String ?? ""
		return "NetNewsWire \(version) (Build \(build))"
	}

	private func exportOPML(account: Account?) {
		guard let account = account,
			  let url = feedsSettingsModel.generateExportURL(for: account) else {
			return
		}

		exportAction(moving: url) { _ in }
	}

	private func importOPML(account: Account?) {
		let types = [UTType(filenameExtension: "opml"), UTType("public.xml")].compactMap { $0 }
		importAction(multipleOfType: types) { (result: Result<[URL], Error>?) in
			if let urls = try? result?.get() {
				feedsSettingsModel.processImportedFiles(urls, account)
			}
		}
	}
}

struct SettingsView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsView()
	}
}
