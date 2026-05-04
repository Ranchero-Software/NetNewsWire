//
//  ArticleFiltersView.swift
//  NetNewsWire
//
//  Created on 3/23/26.
//

import SwiftUI
import Account
import Articles

struct ArticleFiltersView: View {
	@ObservedObject var viewModel: ArticleFiltersViewModel
	@Environment(\.dismiss) private var dismiss
	var onDismiss: (() -> Void)?

	var body: some View {
		#if os(macOS)
		macOSBody
		#else
		iOSBody
		#endif
	}

	#if os(macOS)
	private var macOSBody: some View {
		VStack(spacing: 0) {
			filterList
				.frame(minWidth: 340, minHeight: 200)
			Divider()
			bottomBar
				.padding(12)
		}
	}
	#else
	private var iOSBody: some View {
		NavigationView {
			filterList
				.navigationTitle("Article Filters")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") { dismiss() }
					}
					ToolbarItem(placement: .bottomBar) {
						addFilterButton
					}
				}
		}
	}
	#endif

	private var filterList: some View {
		List {
			if viewModel.filters.isEmpty {
				Text("No filters. Articles matching a filter will be automatically marked as read.")
					.foregroundStyle(.secondary)
					.font(.callout)
			} else {
				ForEach(Array(viewModel.filters.enumerated()), id: \.offset) { index, filter in
					filterRow(filter, at: index)
				}
				.onDelete { indexSet in
					viewModel.removeFilters(at: indexSet)
				}
			}

			if viewModel.isAddingFilter {
				newFilterRow
			}
		}
	}

	private func filterRow(_ filter: ArticleFilter, at index: Int) -> some View {
		HStack {
			VStack(alignment: .leading, spacing: 2) {
				Text(filter.keyword)
					.font(.body)
				Text(filter.matchType == .contains ? "Hide articles with this keyword" : "Only show articles with this keyword")
					.font(.caption)
					.foregroundStyle(.secondary)
				Text("in: \(fieldNames(filter.matchFields))")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Spacer()
			#if os(macOS)
			Button(role: .destructive) {
				viewModel.removeFilter(at: index)
			} label: {
				Image(systemName: "trash")
			}
			.buttonStyle(.borderless)
			#endif
		}
	}

	private func fieldNames(_ fields: ArticleFilter.MatchFields?) -> String {
		let f = fields ?? .all
		var names = [String]()
		if f.contains(.tag) { names.append("Tag") }
		if f.contains(.title) { names.append("Title") }
		if f.contains(.content) { names.append("Content") }
		if f.contains(.summary) { names.append("Summary") }
		return names.isEmpty ? "All" : names.joined(separator: ", ")
	}

	private var newFilterRow: some View {
		VStack(alignment: .leading, spacing: 8) {
			TextField("Keyword (e.g. AI, space, podcast)", text: $viewModel.newKeyword)
				#if os(iOS)
				.textInputAutocapitalization(.never)
				#endif
				.onSubmit {
					viewModel.commitNewFilter()
				}
			Picker("Action", selection: $viewModel.newMatchType) {
				Text("Hide articles with keyword").tag(ArticleFilter.MatchType.contains)
				Text("Only show articles with keyword").tag(ArticleFilter.MatchType.doesNotContain)
			}
			#if os(macOS)
			.pickerStyle(.radioGroup)
			#else
			.pickerStyle(.menu)
			#endif
			HStack(spacing: 12) {
				Text("Match in:").font(.callout)
				Toggle("Tag", isOn: $viewModel.matchInTag)
				Toggle("Title", isOn: $viewModel.matchInTitle)
				Toggle("Content", isOn: $viewModel.matchInContent)
				Toggle("Summary", isOn: $viewModel.matchInSummary)
			}
			#if os(macOS)
			.toggleStyle(.checkbox)
			#endif
			HStack {
				Button("Cancel") {
					viewModel.cancelNewFilter()
				}
				Spacer()
				Button("Add") {
					viewModel.commitNewFilter()
				}
				.disabled(viewModel.newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
			}
		}
		.padding(.vertical, 4)
	}

	#if os(macOS)
	private var bottomBar: some View {
		HStack {
			addFilterButton
			Spacer()
			Button("Done") { performDismiss() }
				.keyboardShortcut(.defaultAction)
		}
	}
	#endif

	private func performDismiss() {
		if let onDismiss {
			onDismiss()
		} else {
			dismiss()
		}
	}

	private var addFilterButton: some View {
		Button {
			viewModel.startAddingFilter()
		} label: {
			Label("Add Filter", systemImage: "plus")
		}
		.disabled(viewModel.isAddingFilter)
	}
}

@MainActor final class ArticleFiltersViewModel: ObservableObject {
	@Published var filters: [ArticleFilter]
	@Published var isAddingFilter = false
	@Published var newKeyword = ""
	@Published var newMatchType: ArticleFilter.MatchType = .contains
	@Published var matchInTag = true
	@Published var matchInTitle = true
	@Published var matchInContent = true
	@Published var matchInSummary = true

	private let feed: Feed

	init(feed: Feed) {
		self.feed = feed
		self.filters = feed.articleFilters ?? []
	}

	func startAddingFilter() {
		isAddingFilter = true
		newKeyword = ""
		newMatchType = .contains
		matchInTag = true
		matchInTitle = true
		matchInContent = true
		matchInSummary = true
	}

	func cancelNewFilter() {
		isAddingFilter = false
		newKeyword = ""
	}

	func commitNewFilter() {
		let keyword = newKeyword.trimmingCharacters(in: .whitespaces)
		guard !keyword.isEmpty else {
			return
		}

		var fields = ArticleFilter.MatchFields()
		if matchInTag { fields.insert(.tag) }
		if matchInTitle { fields.insert(.title) }
		if matchInContent { fields.insert(.content) }
		if matchInSummary { fields.insert(.summary) }
		let matchFields: ArticleFilter.MatchFields? = fields == .all ? nil : fields

		let filter = ArticleFilter(keyword: keyword, matchType: newMatchType, matchFields: matchFields)
		filters.append(filter)
		save()
		isAddingFilter = false
		newKeyword = ""
	}

	func removeFilter(at index: Int) {
		filters.remove(at: index)
		save()
	}

	func removeFilters(at indexSet: IndexSet) {
		filters.remove(atOffsets: indexSet)
		save()
	}

	private func save() {
		feed.articleFilters = filters.isEmpty ? nil : filters
		applyFiltersToExistingArticles()
	}

	private func applyFiltersToExistingArticles() {
		guard let account = feed.account, !filters.isEmpty else {
			return
		}
		Task {
			let articles = try await account.fetchArticlesAsync(.feed(feed))
			let unreadArticles = articles.filter { !$0.status.read }
			var articlesToMarkRead = Set<Article>()
			for article in unreadArticles {
				if filters.anyFilterMatches(article) {
					articlesToMarkRead.insert(article)
				}
			}
			guard !articlesToMarkRead.isEmpty else {
				return
			}
			account.markArticles(articlesToMarkRead, statusKey: .read, flag: true) { _ in }
		}
	}
}
