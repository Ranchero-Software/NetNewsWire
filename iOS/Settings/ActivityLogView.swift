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
				ContentUnavailableView(NSLocalizedString("No Activity Logged", comment: "Activity log empty state"), systemImage: "checkmark.circle")
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
		.navigationTitle(NSLocalizedString("Activity Log", comment: "Activity Log screen title"))
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
		Text("Activity may contain feed URLs and other information you may not want to share publicly.", comment: "Activity log privacy warning")
			.font(.footnote)
			.foregroundStyle(.secondary)
			.padding()
	}

	private var helpLinkFooter: some View {
		Button(NSLocalizedString("Activity Log Help", comment: "Help link")) {
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
	/// the activities. Uses NSMutableAttributedString — appending hundreds of times to a
	/// value-type AttributedString is slow enough to stall the screen as it appears.
	func reload() {
		let entries = ActivityLog.shared.completedActivities
		let attributed = NSMutableAttributedString()
		var plain = ""

		for entry in entries {
			for segment in ActivityLogViewModel.segments(for: entry) {
				attributed.append(NSAttributedString(string: segment.text, attributes: [
					.foregroundColor: uiColor(for: segment.color),
					.font: font(for: segment.weight)
				]))
				plain += segment.text
			}
			attributed.append(NSAttributedString(string: "\n\n"))
			plain += "\n\n"
		}

		isEmpty = entries.isEmpty
		attributedText = AttributedString(attributed)
		plainText = plain
	}

	func uiColor(for color: ActivityLogTextColor) -> UIColor {
		switch color {
		case .primary:
			return .label
		case .secondary:
			return .secondaryLabel
		case .success:
			return .systemGreen
		case .failure:
			return .systemRed
		case .account(let accountID):
			guard let accountID, let account = AccountManager.shared.existingAccount(accountID: accountID) else {
				return .secondaryLabel
			}
			return UIColor(account.type.logColor)
		}
	}

	func font(for weight: ActivityLogTextWeight) -> UIFont {
		let uiWeight: UIFont.Weight
		switch weight {
		case .regular:
			uiWeight = .regular
		case .medium:
			uiWeight = .medium
		case .bold:
			uiWeight = .bold
		}
		let bodySize = UIFont.preferredFont(forTextStyle: .body).pointSize
		return UIFont.monospacedSystemFont(ofSize: bodySize, weight: uiWeight)
	}
}
