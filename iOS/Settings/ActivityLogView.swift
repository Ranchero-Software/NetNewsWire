//
//  ActivityLogView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 6/11/26.
//

import SwiftUI
import Account
import ActivityLog
import RSCore

struct ActivityLogView: View {

	private static let helpURL = URL(string: "https://netnewswire.com/help/activity-log.html")!

	@State private var isEmpty = true
	@State private var attributedText = AttributedString()
	@State private var plainText = ""
	@State private var showHelp = false

	var body: some View {
		VStack(spacing: 0) {
			if isEmpty {
				ContentUnavailableView("No Activity Logged", systemImage: "checkmark.circle")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				privacyWarning
				Divider()
				ScrollView {
					Text(attributedText)
						.font(.system(.body, design: .monospaced))
						.textSelection(.enabled)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding()
				}
			}
			Divider()
			helpLinkFooter
		}
		.navigationTitle("Activity Log")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("Copy Contents") {
					UIPasteboard.general.string = plainText
				}
				.disabled(isEmpty)
			}
		}
		.sheet(isPresented: $showHelp) {
			SafariView(url: Self.helpURL)
		}
		.task {
			reload()
		}
		.onReceive(NotificationCenter.default.publisher(for: .activityDidChange)) { _ in
			reload()
		}
	}

	private var privacyWarning: some View {
		Text("Activity may contain feed URLs and other information you may not want to share publicly.")
			.font(.footnote)
			.foregroundStyle(.secondary)
			.padding()
	}

	private var helpLinkFooter: some View {
		Button("Activity Log Help") {
			showHelp = true
		}
		.font(.subheadline)
		.frame(maxWidth: .infinity)
		.padding(.vertical, 12)
	}
}

// MARK: - Private

private extension ActivityLogView {

	/// Builds the attributed and plain text once per change, from a single pass over
	/// the activities, so the body doesn't rebuild them on every render.
	func reload() {
		let entries = ActivityLog.shared.completedActivities
		var attributed = AttributedString()
		var plain = ""

		for entry in entries {
			for segment in ActivityLogViewModel.segments(for: entry) {
				var piece = AttributedString(segment.text)
				piece.foregroundColor = color(for: segment.color)
				piece.font = .system(.body, design: .monospaced).weight(fontWeight(for: segment.weight))
				attributed.append(piece)
				plain += segment.text
			}
			attributed.append(AttributedString("\n\n"))
			plain += "\n\n"
		}

		isEmpty = entries.isEmpty
		attributedText = attributed
		plainText = plain
	}

	func color(for color: ActivityLogTextColor) -> Color {
		switch color {
		case .primary:
			return .primary
		case .secondary:
			return .secondary
		case .success:
			return .green
		case .failure:
			return .red
		case .account(let accountID):
			guard let accountID, let account = AccountManager.shared.existingAccount(accountID: accountID) else {
				return .secondary
			}
			return account.type.logColor
		}
	}

	func fontWeight(for weight: ActivityLogTextWeight) -> Font.Weight {
		switch weight {
		case .regular:
			return .regular
		case .medium:
			return .medium
		case .bold:
			return .bold
		}
	}
}
