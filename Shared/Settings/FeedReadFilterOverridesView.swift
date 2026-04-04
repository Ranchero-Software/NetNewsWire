//
//  FeedReadFilterOverridesView.swift
//  NetNewsWire
//
//  Created by Paul on 4/1/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account

@MainActor struct FeedReadFilterOverridesView: View {

	let account: Account
	let hasOverride: (_ feedID: String) -> Bool
	let setOverride: (_ feedID: String, _ hasOverride: Bool) -> Void
	let clearAllOverrides: () -> Void

	#if os(macOS)
	var onDone: (() -> Void)?
	#endif

	@State private var feeds = [Feed]()
	@State private var overrideStates = [String: Bool]()

	var body: some View {

		List {
			Section {
				ForEach(feeds, id: \.feedID) { feed in
					Toggle(feed.nameForDisplay, isOn: Binding(
						get: { overrideStates[feed.feedID] ?? false },
						set: { overrideStates[feed.feedID] = $0 }
					))
					.onChange(of: overrideStates[feed.feedID]) {
						setOverride(feed.feedID, overrideStates[feed.feedID] ?? false)
					}
				}
			} footer: {
				Text("When a switch is on, that feed uses its own read-article visibility setting instead of the global preference.")
			}
		}
		.onAppear {
			feeds = Array(account.flattenedFeeds()).sorted { $0.nameForDisplay.localizedStandardCompare($1.nameForDisplay) == .orderedAscending }
			var states = [String: Bool]()
			for feed in feeds {
				states[feed.feedID] = hasOverride(feed.feedID)
			}
			overrideStates = states
		}
		.toolbar {
			#if os(macOS)
			ToolbarItem(placement: .cancellationAction) {
				Button("Done") {
					onDone?()
				}
			}
			#endif
			ToolbarItem(placement: .primaryAction) {
				Button("Clear All", action: clearAll)
			}
		}
		#if os(iOS)
		.navigationTitle("Override Global Setting")
		.navigationBarTitleDisplayMode(.inline)
		#else
		.frame(minWidth: 400, minHeight: 300)
		#endif
	}

	private func clearAll() {
		clearAllOverrides()
		for key in overrideStates.keys {
			overrideStates[key] = false
		}
	}
}
