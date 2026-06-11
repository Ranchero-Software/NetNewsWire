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

	@State private var entries = [Activity]()
	@State private var plainText = ""

	var body: some View {
		Group {
			if entries.isEmpty {
				ContentUnavailableView("No Activity Logged", systemImage: "checkmark.circle")
			} else {
				VStack(spacing: 0) {
					privacyWarning
					Divider()
					ScrollView {
						Text(buildAttributedString(entries))
							.font(.system(.body, design: .monospaced))
							.textSelection(.enabled)
							.frame(maxWidth: .infinity, alignment: .leading)
							.padding()
					}
				}
			}
		}
		.navigationTitle("Activity Log")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("Copy Contents") {
					UIPasteboard.general.string = plainText
				}
				.disabled(entries.isEmpty)
			}
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
}

// MARK: - Private

private extension ActivityLogView {

	func reload() {
		entries = ActivityLog.shared.completedActivities
		plainText = buildPlainText(entries)
	}

	func buildAttributedString(_ entries: [Activity]) -> AttributedString {
		var result = AttributedString()
		for entry in entries {
			result.append(attributedString(for: entry))
			result.append(AttributedString("\n\n"))
		}
		return result
	}

	func attributedString(for activity: Activity) -> AttributedString {
		var result = AttributedString()
		for segment in ActivityLogViewModel.segments(for: activity) {
			var piece = AttributedString(segment.text)
			piece.foregroundColor = color(for: segment.color)
			piece.font = .system(.body, design: .monospaced).weight(fontWeight(for: segment.weight))
			result.append(piece)
		}
		return result
	}

	func buildPlainText(_ entries: [Activity]) -> String {
		var result = ""
		for entry in entries {
			result += ActivityLogViewModel.plainText(for: entry)
			result += "\n\n"
		}
		return result
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
