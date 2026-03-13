//
//  ErrorLogView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 3/13/26.
//

import SwiftUI
import Account
import ErrorLog

struct ErrorLogView: View {

	@State private var entries = [ErrorLogEntry]()
	@State private var plainText = ""

	private static let maxEntries = 200

	var body: some View {
		Group {
			if entries.isEmpty {
				ContentUnavailableView("No Errors", systemImage: "checkmark.circle")
			} else {
				ScrollView {
					Text(buildAttributedString(entries))
						.font(.system(.body, design: .monospaced))
						.textSelection(.enabled)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding()

					privacyWarning
				}
			}
		}
		.navigationTitle("Errors")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("Copy Contents") {
					UIPasteboard.general.string = plainText
				}
				.disabled(entries.isEmpty)
			}
		}
		.task {
			let allEntries = await AccountManager.shared.errorLogDatabase.allEntries()
			entries = Array(allEntries.suffix(Self.maxEntries))
			plainText = buildPlainText(entries)
		}
		.onReceive(NotificationCenter.default.publisher(for: .appDidEncounterError)) { notification in
			guard let entry = errorLogEntry(from: notification) else {
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
			.padding(.horizontal)
			.padding(.bottom)
	}
}

// MARK: - Private

private extension ErrorLogView {

	static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		return formatter
	}()

	func buildAttributedString(_ entries: [ErrorLogEntry]) -> AttributedString {
		var result = AttributedString()
		for entry in entries {
			result.append(attributedString(for: entry))
		}
		return result
	}

	func attributedString(for entry: ErrorLogEntry) -> AttributedString {
		var timestamp = AttributedString("[\(Self.dateFormatter.string(from: entry.date))] ")
		timestamp.foregroundColor = .secondary

		let sourceString: String
		if entry.operation.isEmpty {
			sourceString = "\(entry.sourceName): "
		} else {
			sourceString = "\(entry.sourceName) — \(entry.operation): "
		}
		var source = AttributedString(sourceString)
		source.foregroundColor = color(for: entry.sourceID)
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

		result.append(AttributedString("\n"))
		return result
	}

	func buildPlainText(_ entries: [ErrorLogEntry]) -> String {
		var result = ""
		for entry in entries {
			result += "[\(Self.dateFormatter.string(from: entry.date))] "
			if entry.operation.isEmpty {
				result += "\(entry.sourceName): "
			} else {
				result += "\(entry.sourceName) \u{2014} \(entry.operation): "
			}
			result += entry.errorMessage
			if !entry.functionName.isEmpty {
				result += " (\(entry.fileName):\(entry.functionName):\(entry.lineNumber))"
			}
			result += "\n"
		}
		return result
	}

	func color(for sourceID: Int) -> Color {
		guard let type = AccountType(rawValue: sourceID) else {
			return .secondary
		}

		switch type {
		case .onMyMac:
			return .secondary
		case .cloudKit:
			return .purple
		case .feedly:
			return .green
		case .feedbin:
			return .blue
		case .newsBlur:
			return .orange
		case .freshRSS:
			return .teal
		case .inoreader:
			return .brown
		case .bazQux:
			return .indigo
		case .theOldReader:
			return .pink
		}
	}

	func errorLogEntry(from notification: Notification) -> ErrorLogEntry? {
		guard let errorMessage = notification.userInfo?[ErrorLogUserInfoKey.errorMessage] as? String,
			  let sourceName = notification.userInfo?[ErrorLogUserInfoKey.sourceName] as? String,
			  let sourceID = notification.userInfo?[ErrorLogUserInfoKey.sourceID] as? Int else {
			return nil
		}
		let operation = notification.userInfo?[ErrorLogUserInfoKey.operation] as? String ?? ""
		let fileName = notification.userInfo?[ErrorLogUserInfoKey.fileName] as? String ?? ""
		let functionName = notification.userInfo?[ErrorLogUserInfoKey.functionName] as? String ?? ""
		let lineNumber = notification.userInfo?[ErrorLogUserInfoKey.lineNumber] as? Int ?? 0

		return ErrorLogEntry(id: 0, date: Date(), sourceName: sourceName, sourceID: sourceID, operation: operation, fileName: fileName, functionName: functionName, lineNumber: lineNumber, errorMessage: errorMessage)
	}
}
