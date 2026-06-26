//
//  FeedReadFilterOverridesView.swift
//  NetNewsWire
//
//  Created by Paul on 4/1/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import Images

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
	@State private var iconRefreshID = UUID()

	var body: some View {

		Group {
			#if os(macOS)
			// On macOS a `List` section footer clips to a single line, so the
			// explanatory text is rendered below the list instead.
			VStack(spacing: 0) {
				feedList
				Text("When a switch is on, that feed uses its own read-article visibility setting instead of the global preference.")
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)
					.fixedSize(horizontal: false, vertical: true)
					.padding()
			}
			#else
			feedList
			#endif
		}
		.onAppear {
			feeds = Array(account.flattenedFeeds()).sorted { $0.nameForDisplay.localizedStandardCompare($1.nameForDisplay) == .orderedAscending }
			var states = [String: Bool]()
			for feed in feeds {
				states[feed.feedID] = hasOverride(feed.feedID)
			}
			overrideStates = states
		}
		.onReceive(NotificationCenter.default.publisher(for: .feedIconDidBecomeAvailable)) { _ in
			iconRefreshID = UUID()
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
		.navigationTitle("Global Overrides")
		.navigationBarTitleDisplayMode(.inline)
		#else
		.frame(minWidth: 400, minHeight: 300)
		#endif
	}

	private var feedList: some View {
		List {
			Section {
				ForEach(feeds, id: \.feedID) { feed in
					Toggle(isOn: Binding(
						get: { overrideStates[feed.feedID] ?? false },
						set: { newValue in
							overrideStates[feed.feedID] = newValue
							setOverride(feed.feedID, newValue)
						}
					)) {
						HStack {
							if let iconImage = iconImage(for: feed) {
								IconImageView(icon: iconImage)
									.id(iconRefreshID)
							}
							Text(verbatim: feed.nameForDisplay)
						}
					}
					.toggleStyle(.switch)
				}
			} footer: {
				#if os(iOS)
				Text("When a switch is on, that feed uses its own read-article visibility setting instead of the global preference.")
				#endif
			}
		}
	}

	private func iconImage(for feed: Feed) -> IconImage? {
		if let feedID = feed.sidebarItemID, let iconImage = IconImageCache.shared.imageFor(feedID) {
			return iconImage
		}
		return feed.smallIcon
	}

	private func clearAll() {
		clearAllOverrides()
		for key in overrideStates.keys {
			overrideStates[key] = false
		}
	}
}
