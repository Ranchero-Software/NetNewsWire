//
//  SettingsView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

struct SettingsView : View {
	@ObjectBinding var viewModel: SettingsViewModel
	
    var body: some View {
		NavigationView {
			List {
				
				Section(header: Text("ACCOUNTS")) {
					ForEach(viewModel.accounts.identified(by: \.self)) { account in
						Text(verbatim: account.nameForDisplay)
					}
					NavigationButton(destination: SettingsAddAccountView(), isDetail: false) {
						Text("Add Account")
					}
				}
				
				Section(header: Text("ABOUT")) {
					
					Text("About NetNewsWire")

					Button(action: {
						UIApplication.shared.open(URL(string: "https://ranchero.com/netnewswire/")!, options: [:])
					}) {
						Text("Website")
					}
					
					Button(action: {
						UIApplication.shared.open(URL(string: "https://github.com/brentsimmons/NetNewsWire")!, options: [:])
					}) {
						Text("Github Repository")
					}

					Button(action: {
						UIApplication.shared.open(URL(string: "https://github.com/brentsimmons/NetNewsWire/issues")!, options: [:])
					}) {
						Text("Bug Tracker")
					}

					Button(action: {
						UIApplication.shared.open(URL(string: "https://github.com/brentsimmons/NetNewsWire/tree/master/Technotes")!, options: [:])
					}) {
						Text("Technotes")
					}

					Text("Add NetNewsWire News Feed")
					
				}
				.foregroundColor(.primary)
				
				Section(header: Text("TIMELINE")) {
					Toggle(isOn: $viewModel.sortOldestToNewest) {
						Text("Sort Oldest to Newest")
					}
					Stepper(value: $viewModel.timelineNumberOfLines, in: 2...6) {
						Text("Number of Text Lines: \(viewModel.timelineNumberOfLines)")
					}
				}
				
				Section(header: Text("DATABASE")) {
					Picker(selection: $viewModel.refreshInterval, label: Text("Refresh Interval")) {
						ForEach(RefreshInterval.allCases.identified(by: \.self)) { interval in
							Text(interval.description()).tag(interval)
						}
					}
					Text("Import Subscriptions...")
					Text("Export Subscriptions...")
				}
				
			}
			.listStyle(.grouped)
			.navigationBarTitle(Text("Settings"), displayMode: .inline)

		}
    }
}

#if DEBUG
struct SettingsView_Previews : PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: SettingsViewModel())
    }
}
#endif
