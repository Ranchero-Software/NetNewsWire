//
//  CurrentActivityView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 6/9/26.
//

import SwiftUI
import RSCore
import ActivityLog

struct CurrentActivityView: View {

	private static let helpURL = URL(string: "https://netnewswire.com/help/current-activity.html")!

	@State private var model = CurrentActivityViewModel()
	@State private var activities = [Activity]()
	@State private var showHelp = false
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		List {
			Section {
				if activities.isEmpty {
					Text(NSLocalizedString("No current activity.", comment: "Current Activity empty state"))
						.foregroundStyle(.secondary)
				} else {
					ForEach(activities, id: \.id) { activity in
						activityRow(activity)
					}
				}
			}

			Section {
			} footer: {
				helpLinkFooter
			}
		}
		.navigationTitle(NSLocalizedString("Current Activity", comment: "Current Activity"))
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			if #available(iOS 26, *) {
				ToolbarItem(placement: .topBarTrailing) {
					Button(role: .close) {
						dismiss()
					}
				}
			} else {
				ToolbarItem(placement: .confirmationAction) {
					Button(NSLocalizedString("Done", comment: "Done")) {
						dismiss()
					}
				}
			}
		}
		.sheet(isPresented: $showHelp) {
			SafariView(url: Self.helpURL)
		}
		.onAppear {
			model.displayedActivitiesDidChange = {
				activities = model.displayedActivities
			}
			model.start()
		}
		.onDisappear {
			model.stop()
		}
	}
}

// MARK: - Private

private extension CurrentActivityView {

	var helpLinkFooter: some View {
		Button(NSLocalizedString("Current Activity Help", comment: "Help link")) {
			showHelp = true
		}
		.font(.subheadline)
		.frame(maxWidth: .infinity)
		.padding(.top, 8)
	}

	func activityRow(_ activity: Activity) -> some View {
		let text = CurrentActivityViewModel.displayText(for: activity)
		return HStack(alignment: .firstTextBaseline, spacing: 10) {
			Image(systemName: CurrentActivityViewModel.symbolName(for: activity.state))
				.foregroundStyle(stateColor(for: activity.state))
				.accessibilityLabel(CurrentActivityViewModel.accessibilityLabel(for: activity.state))
			VStack(alignment: .leading, spacing: 2) {
				Text(activity.owner.displayName)
					.font(.footnote)
					.foregroundStyle(.secondary)
				Text(text.title)
					.lineLimit(1)
					.truncationMode(.tail)
				if let detail = text.detail {
					Text(detail)
						.font(.footnote)
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.truncationMode(.middle)
				}
			}
		}
	}

	func stateColor(for state: ActivityState) -> Color {
		switch state {
		case .pending:
			return .secondary
		case .running:
			return .blue
		case .completed:
			return .green
		case .failed:
			return .red
		}
	}
}
