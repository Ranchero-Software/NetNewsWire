//
//  SettingsView.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 30/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account



class SettingsViewModel: ObservableObject {
	
	enum HelpSites {
		case netNewsWireHelp, netNewsWire, supportNetNewsWire, github, bugTracker, technotes, netNewsWireSlack, none
		
		var url: URL? {
			switch self {
			case .netNewsWireHelp:
				return URL(string: "https://ranchero.com/netnewswire/help/ios/5.0/en/")!
			case .netNewsWire:
				return URL(string: "https://ranchero.com/netnewswire/")!
			case .supportNetNewsWire:
				return URL(string: "https://github.com/brentsimmons/NetNewsWire/blob/master/Technotes/HowToSupportNetNewsWire.markdown")!
			case .github:
				return URL(string: "https://github.com/brentsimmons/NetNewsWire")!
			case .bugTracker:
				return URL(string: "https://github.com/brentsimmons/NetNewsWire/issues")!
			case .technotes:
				return URL(string: "https://github.com/brentsimmons/NetNewsWire/tree/master/Technotes")!
			case .netNewsWireSlack:
				return URL(string: "https://ranchero.com/netnewswire/slack")!
			case .none:
				return nil
			}
		}
	}
	
	@Published var presentSheet: Bool = false
	var selectedWebsite: HelpSites = .none {
		didSet {
			if selectedWebsite == .none {
				presentSheet = false
			} else {
				presentSheet = true
			}
		}
	}
	
}

struct SettingsView: View {
	
	let sortedAccounts = AccountManager.shared.sortedAccounts
	@Environment(\.presentationMode) var presentationMode
	
	@StateObject private var viewModel = SettingsViewModel()
	
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
			ForEach(0..<sortedAccounts.count, content: { i in
				NavigationLink(
					destination: EmptyView(),
					label: {
						Text(sortedAccounts[i].nameForDisplay)
					})
			})
			NavigationLink(
				destination: EmptyView(),
				label: {
					Text("Add Account")
				})
		})
	}
	
	var importExport: some View {
		Section(header: Text("Feeds"), content: {
			NavigationLink(
				destination: EmptyView(),
				label: {
					Text("Import Subscriptions")
				})
			NavigationLink(
				destination: EmptyView(),
				label: {
					Text("Export Subscriptions")
				})
		})
	}
	
	var timeline: some View {
		Section(header: Text("Timeline"), content: {
			Toggle("Sort Oldest to Newest", isOn: .constant(true))
			Toggle("Group by Feed", isOn: .constant(true))
			Toggle("Refresh to Clear Read Articles", isOn: .constant(true))
			NavigationLink(
				destination: EmptyView(),
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
				destination: EmptyView(),
				label: {
					HStack {
						Text("Color Pallete")
						Spacer()
						Text("Automatic")
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
				destination: EmptyView(),
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
	
}

struct SettingsView_Previews: PreviewProvider {
	static var previews: some View {
		SettingsView()
	}
}
