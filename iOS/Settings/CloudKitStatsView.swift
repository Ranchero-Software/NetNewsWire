//
//  CloudKitStatsView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 3/20/26.
//

import SwiftUI
import SafariServices
import Account

struct CloudKitStatsView: View {

	private static let model = CloudKitStatsViewModel()
	private static let helpURL = URL(string: "https://netnewswire.com/help/optimize-icloud.html")!
	private let model = CloudKitStatsView.model

	@State private var showCleanUpConfirmation = false
	@State private var showHelp = false

	var body: some View {
		List {
			if model.cleanUpStatus.isActive {
				cleanUpStatusSection
				cleanUpResultsSection
				cleanUpNavigationSection
			} else {
				statusSection
				if let fetchError = model.fetchStatus.fetchError {
					Section {
						Text(fetchError.localizedDescription)
							.foregroundStyle(.red)
					}
				} else {
					statusRecordsSection
					contentRecordsSection
				}
				if model.canCleanUp {
					Section {
						Button(NSLocalizedString("Clean Up…", comment: "Clean up button")) {
							showCleanUpConfirmation = true
						}
					} footer: {
						helpLinkFooter
					}
				} else {
					Section {
					} footer: {
						helpLinkFooter
					}
				}
			}
		}
		.navigationTitle(NSLocalizedString("iCloud Storage Stats", comment: "Navigation title for iCloud stats view"))
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				if model.fetchStatus.isFetching {
					Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
						model.cancelFetch()
					}
				} else if model.cleanUpStatus.isCleaning {
					Button(NSLocalizedString("Cancel", comment: "Cancel button")) {
						model.cancelCleanUp()
					}
				} else {
					Menu {
						ShareLink(item: model.cleanUpStatus.isActive ? model.cleanUpStatsText : model.statsText) {
							Label(NSLocalizedString("Share Stats", comment: "Share stats menu item"), systemImage: "square.and.arrow.up")
						}
						Link(destination: Self.helpURL) {
							Label(NSLocalizedString("Help", comment: "Help menu item"), systemImage: "questionmark.circle")
						}
					} label: {
						Label(NSLocalizedString("More", comment: "More menu label"), systemImage: "ellipsis.circle")
					}
					.disabled(!model.fetchStatus.isCompleted && !model.cleanUpStatus.isActive)
				}
			}
		}
		.alert(NSLocalizedString("Clean Up iCloud Records", comment: "Clean up alert title"), isPresented: $showCleanUpConfirmation) {
			Button(NSLocalizedString("Clean Up", comment: "Clean up alert button"), role: .destructive) {
				model.cleanUp()
			}
			Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
			}
		} message: {
			Text(cleanUpConfirmationMessage())
		}
		.sheet(isPresented: $showHelp) {
			SafariView(url: Self.helpURL)
		}
		.onAppear {
			if case .idle = model.fetchStatus {
				model.fetch()
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
			if model.fetchStatus.isFetching {
				model.cancelFetch()
			}
			if model.cleanUpStatus.isCleaning {
				model.cancelCleanUp()
			}
		}
	}

	// MARK: - Scan Sections

	@ViewBuilder private var statusSection: some View {
		Section {
			switch model.fetchStatus {
			case .idle:
				EmptyView()
			case .fetching:
				HStack(spacing: 6) {
					ProgressView()
						.controlSize(.small)
					Text(NSLocalizedString("Scanning iCloud storage", comment: "Scan status text"))
						.foregroundStyle(.secondary)
				}
				.id("fetching")
			case .completed:
				HStack(spacing: 4) {
					Image(systemName: "checkmark.circle.fill")
						.foregroundStyle(.green)
					Text(NSLocalizedString("Scan completed.", comment: "Scan completed text"))
						.foregroundStyle(.secondary)
					Spacer()
					Button(NSLocalizedString("Refresh", comment: "Refresh button")) {
						model.fetch()
					}
				}
			case .canceled:
				statusRow(NSLocalizedString("Canceled.", comment: "Scan canceled text"))
			case .error:
				statusRow(NSLocalizedString("Scan failed.", comment: "Scan failed text"))
			}
		}
	}

	private var statusRecordsSection: some View {
		Section {
			statsRow(NSLocalizedString("Status Records", comment: "Status records header"), model.stats.statusCount, isHeader: true)
			iconStatsRow(NSLocalizedString("Starred", comment: "Starred label"), systemImage: "star.fill", iconColor: .yellow, model.stats.starredStatusCount, iconBaselineOffset: 1)
			iconStatsRow(NSLocalizedString("Unread", comment: "Unread label"), systemImage: "circle.fill", iconColor: .accentColor, model.stats.unreadStatusCount)
			statsRow(NSLocalizedString("Read", comment: "Read label"), model.stats.readStatusCount)
		}
	}

	private var helpLinkFooter: some View {
		Button(NSLocalizedString("How to Optimize iCloud Syncing", comment: "Help link")) {
			showHelp = true
		}
		.font(.subheadline)
		.frame(maxWidth: .infinity)
		.padding(.top, 8)
	}

	private var contentRecordsSection: some View {
		Section {
			statsRow(NSLocalizedString("Article Content Records", comment: "Article content records header"), model.stats.articleCount, isHeader: true)
			iconStatsRow(NSLocalizedString("Starred", comment: "Starred label"), systemImage: "star.fill", iconColor: .yellow, model.stats.starredArticleCount, iconBaselineOffset: 1)
			iconStatsRow(NSLocalizedString("Unread", comment: "Unread label"), systemImage: "circle.fill", iconColor: .accentColor, model.stats.unreadArticleCount, isWarning: !syncUnreadContent)
			statsRow(NSLocalizedString("Read", comment: "Read label"), model.stats.readArticleCount, isWarning: true)
		}
	}

	// MARK: - Clean Up Sections

	@ViewBuilder private var cleanUpStatusSection: some View {
		Section {
			if model.cleanUpStatus.cleanUpError != nil {
				Text(NSLocalizedString("Cleanup failed to complete, but you may be able to clean up more if you wait a few minutes and try again.", comment: "Cleanup error message"))
					.foregroundStyle(.red)
				Button(NSLocalizedString("Refresh", comment: "Refresh button")) {
					model.fetch()
				}
			} else if let progress = model.cleanUpStatus.progress {
				if model.cleanUpStatus.isCanceled {
					ProgressView(value: fractionComplete(progress))
					Text(NSLocalizedString("Cleanup canceled.", comment: "Cleanup status text when canceled"))
						.foregroundStyle(.secondary)
				} else if model.cleanUpStatus.isCompleted {
					ProgressView(value: 1.0)
					Text(NSLocalizedString("iCloud storage cleanup completed.", comment: "Cleanup phase text when completed"))
						.foregroundStyle(.secondary)
				} else {
					ProgressView(value: fractionComplete(progress))
					Text(cleanUpPhaseText(progress.phase))
						.foregroundStyle(.secondary)
				}
			}
		}
	}

	@ViewBuilder private var cleanUpResultsSection: some View {
		if let progress = model.cleanUpStatus.progress {
			Section {
				if progress.readContentDeleted > 0 || progress.phase == .deletingReadContent {
					statsRow(NSLocalizedString("Read Content Deleted", comment: "Read content deleted label"), progress.readContentDeleted)
				}
				if progress.unreadContentDeleted > 0 || progress.phase == .deletingUnreadContent {
					statsRow(NSLocalizedString("Unread Content Deleted", comment: "Unread content deleted label"), progress.unreadContentDeleted)
				}
			}
		}
	}

	@ViewBuilder private var cleanUpNavigationSection: some View {
		if model.cleanUpStatus.isCompleted || model.cleanUpStatus.isCanceled {
			Section {
				Button(NSLocalizedString("Return to Previous Scan Results", comment: "Return to scan results button")) {
					withAnimation(.easeInOut(duration: 0.25)) {
						model.cleanUpStatus = .idle
					}
				}
				Button(NSLocalizedString("Refresh Scan", comment: "Refresh scan button")) {
					withAnimation(.easeInOut(duration: 0.25)) {
						model.fetch()
					}
				}
			}
		}
	}

	// MARK: - Shared Helpers

	private var syncUnreadContent: Bool {
		UserDefaults.standard.bool(forKey: Account.iCloudSyncArticleContentForUnreadArticlesKey)
	}

	private func iconStatsRow(_ label: String, systemImage: String, iconColor: Color, _ count: Int, iconBaselineOffset: CGFloat = 0, isWarning: Bool = false) -> some View {
		HStack {
			HStack(spacing: 4) {
				Text(label)
				Image(systemName: systemImage)
					.foregroundStyle(iconColor)
					.imageScale(.small)
					.baselineOffset(iconBaselineOffset)
			}
			Spacer()
			Text(formattedNumber(count))
				.monospacedDigit()
				.foregroundStyle(countColor(isWarning: isWarning, count: count))
		}
	}

	private func statsRow(_ label: String, _ count: Int, isHeader: Bool = false, isWarning: Bool = false) -> some View {
		HStack {
			Text(label)
				.fontWeight(isHeader ? .semibold : .regular)
			Spacer()
			Text(formattedNumber(count))
				.monospacedDigit()
				.foregroundStyle(countColor(isWarning: isWarning, count: count))
		}
	}

	private func statusRow(_ text: String) -> some View {
		HStack(spacing: 4) {
			Text(text)
				.foregroundStyle(.secondary)
			Spacer()
			Button(NSLocalizedString("Refresh", comment: "Refresh button")) {
				model.fetch()
			}
		}
	}

	private func countColor(isWarning: Bool, count: Int) -> AnyShapeStyle {
		if model.fetchStatus.isFetching || model.cleanUpStatus.isCleaning {
			return AnyShapeStyle(.secondary)
		}
		if isWarning && count > 0 {
			return AnyShapeStyle(.orange)
		}
		return AnyShapeStyle(.primary)
	}

	// MARK: - Private Helpers

	private func cleanUpConfirmationMessage() -> String {
		if model.cleanUpPlanIsStale {
			return staleCleanUpConfirmationText()
		}
		return cleanUpConfirmationText(model.cleanUpPlan)
	}

	private func cleanUpConfirmationText(_ plan: CloudKitCleanUpPlan) -> String {
		var lines = [String]()
		if plan.readContentCount > 0 {
			lines.append(formattedCount(plan.readContentCount, singular: NSLocalizedString("read content record", comment: "Singular label for read content records"), plural: NSLocalizedString("read content records", comment: "Plural label for read content records")))
		}
		if plan.unreadContentCount > 0 {
			lines.append(formattedCount(plan.unreadContentCount, singular: NSLocalizedString("unread content record", comment: "Singular label for unread content records"), plural: NSLocalizedString("unread content records", comment: "Plural label for unread content records")))
		}
		let listText = lines.map { "• " + $0 }.joined(separator: "\n")
		return NSLocalizedString("This will delete:", comment: "Clean up confirmation prefix") + "\n" + listText + "\n\n" + NSLocalizedString("This may take several minutes.", comment: "Clean up confirmation suffix")
	}

	private func staleCleanUpConfirmationText() -> String {
		if syncUnreadContent {
			return NSLocalizedString("This will delete any read content records.\n\nThis may take several minutes.", comment: "Clean up confirmation when sync unread is on and plan is stale")
		} else {
			return NSLocalizedString("This will delete any not-starred content records.\n\nThis may take several minutes.", comment: "Clean up confirmation when plan is stale")
		}
	}

	private func cleanUpPhaseText(_ phase: CloudKitCleanUpPhase) -> String {
		switch phase {
		case .deletingStaleStatus:
			return ""
		case .deletingReadContent:
			return NSLocalizedString("Deleting read content records…", comment: "Cleanup phase text")
		case .deletingUnreadContent:
			return NSLocalizedString("Deleting unread content records…", comment: "Cleanup phase text")
		case .completed:
			return NSLocalizedString("iCloud storage cleanup completed.", comment: "Cleanup phase text when completed")
		}
	}

	private func fractionComplete(_ progress: CloudKitCleanUpProgress) -> Double {
		let totalCount = model.cleanUpPlan.totalCount
		guard totalCount > 0 else {
			return 0
		}
		return Double(progress.totalDeleted) / Double(totalCount)
	}

	private func formattedNumber(_ value: Int) -> String {
		NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
	}

	private func formattedCount(_ count: Int, singular: String, plural: String) -> String {
		let label = count == 1 ? singular : plural
		return "\(formattedNumber(count)) \(label)"
	}
}

private struct SafariView: UIViewControllerRepresentable {

	let url: URL

	func makeUIViewController(context: Context) -> SFSafariViewController {
		SFSafariViewController(url: url)
	}

	func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
	}
}
