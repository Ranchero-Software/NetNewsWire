//
//  ErrorLogView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 3/13/26.
//

import SwiftUI
import Account
import ErrorLog
import RSCore

struct ErrorLogView: View {

	@State private var entries = [ErrorLogEntry]()
	@State private var plainText = ""
	@State private var showHelp = false

	private static let maxEntries = 200
	private static let helpURL = URL(string: "https://netnewswire.com/help/error-log.html")!

	var body: some View {
		VStack(spacing: 0) {
			if entries.isEmpty {
				ContentUnavailableView(NSLocalizedString("No Errors Logged", comment: "Error log empty state"), systemImage: "checkmark.circle")
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
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
			Divider()
			helpLinkFooter
		}
		.navigationTitle("Error Log")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("Copy Contents") {
					UIPasteboard.general.string = plainText
				}
				.disabled(entries.isEmpty)
			}
		}
		.sheet(isPresented: $showHelp) {
			SafariView(url: Self.helpURL)
		}
		.task {
			let allEntries = await AccountManager.shared.errorLogDatabase.allEntries()
			entries = Array(allEntries.suffix(Self.maxEntries))
			plainText = buildPlainText(entries)
		}
		.onReceive(NotificationCenter.default.publisher(for: .appDidEncounterError)) { notification in
			guard let entry = ErrorLogEntry(notification: notification) else {
				return
			}
			entries.append(entry)
			if entries.count > Self.maxEntries {
				entries.removeFirst(entries.count - Self.maxEntries)
			}
			plainText = buildPlainText(entries)
		}
	}

	private var privacyWarning: some View {
		Text("Errors may contain feed URLs and other information you may not want to share publicly.")
			.font(.footnote)
			.foregroundStyle(.secondary)
			.padding()
	}

	private var helpLinkFooter: some View {
		Button(NSLocalizedString("Error Log Help", comment: "Help link")) {
			showHelp = true
		}
		.font(.subheadline)
		.frame(maxWidth: .infinity)
		.padding(.vertical, 12)
	}
}

// MARK: - Private

private extension ErrorLogView {

	func buildAttributedString(_ entries: [ErrorLogEntry]) -> AttributedString {
		var result = AttributedString()
		for entry in entries {
			result.append(attributedString(for: entry))
		}
		return result
	}

	func attributedString(for entry: ErrorLogEntry) -> AttributedString {
		var timestamp = AttributedString("[\(DateFormatter.logTimestamp.string(from: entry.date))] ")
		timestamp.foregroundColor = .secondary

		let sourceString: String
		if entry.operation.isEmpty {
			sourceString = "\(entry.sourceName): "
		} else {
			sourceString = "\(entry.sourceName) — \(entry.operation): "
		}
		var source = AttributedString(sourceString)
		source.foregroundColor = AccountType(rawValue: entry.sourceID)?.logColor ?? .secondary
		source.font = .system(.body, design: .monospaced).weight(.medium)

		var message = AttributedString(entry.errorMessage)
		message.foregroundColor = .primary

		var result = timestamp
		result.append(source)
		result.append(message)

		if !entry.functionName.isEmpty {
			var location = AttributedString(" (\(entry.fileName):\(entry.functionName):\(entry.lineNumber))")
			location.foregroundColor = Color(uiColor: .tertiaryLabel)
			result.append(location)
		}

		result.append(AttributedString("\n\n"))
		return result
	}

	func buildPlainText(_ entries: [ErrorLogEntry]) -> String {
		var result = ""
		for entry in entries {
			result += "[\(DateFormatter.logTimestamp.string(from: entry.date))] "
			if entry.operation.isEmpty {
				result += "\(entry.sourceName): "
			} else {
				result += "\(entry.sourceName) — \(entry.operation): "
			}
			result += entry.errorMessage
			if !entry.functionName.isEmpty {
				result += " (\(entry.fileName):\(entry.functionName):\(entry.lineNumber))"
			}
			result += "\n\n"
		}
		return result
	}
}
