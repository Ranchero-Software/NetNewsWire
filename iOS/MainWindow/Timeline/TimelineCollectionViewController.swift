//
//  TimelineCollectionViewController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 2/9/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit
import Account
import Articles
import RSCore
import RSDatabase

typealias TimelineSectionID = Int
typealias TimelineArticleID = String

final class TimelineCell: UICollectionViewCell {

	static let reuseIdentifier = "TimelineCell"

	let titleLabel: UILabel = {
		let label = UILabel()
		label.font = UIFont.boldSystemFont(ofSize: 16)
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	override init(frame: CGRect) {
		super.init(frame: frame)

		contentView.addSubview(titleLabel)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - API

	func configure(_ article: Article?, showFeedName: Bool, showIcon: Bool) {
		if let article {
			titleLabel.text = article.title
		} else {
			titleLabel.text = "Untitled"
		}
	}

	// MARK: - UIView

	override func layoutSubviews() {
		var r = titleLabel.frame
		r.origin.x = 16
		r.size.width = contentView.bounds.width - 32
		r.size.height = contentView.bounds.height
		titleLabel.setFrameIfNotEqual(r)
	}
}

final class TimelineArticlesManager {

	var articles = [Article]() {
		didSet {
			updateArticleIDsToArticles()
		}
	}

	subscript(_ articleID: String) -> Article? {
		articleIDsToArticles[articleID]
	}

	private var articleIDsToArticles = [String: Article]()

	private func updateArticleIDsToArticles() {
		var d = [String: Article]()
		for article in articles {
			d[article.id] = article
		}
		articleIDsToArticles = d
	}
}

final class TimelineCollectionViewController: UICollectionViewController {

	var items = [any Item]() {
		didSet {
			updateTitle()
			updateArticles()
		}
	}

	private static var defaultTitle = "Articles" // TODO: localize
	private static var multipleItemsTitle = "Multiple" // TODO: localize

	private let timelineArticlesManager = TimelineArticlesManager()
	private var fetchArticlesTask: Task<Void, Never>?

	typealias DataSource = UICollectionViewDiffableDataSource<TimelineSectionID, TimelineArticleID>
	private lazy var dataSource = createDataSource()

	init() {
		var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
		configuration.headerMode = .none
		let layout = UICollectionViewCompositionalLayout.list(using: configuration)

		super.init(collectionViewLayout: layout)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.largeTitleDisplayMode = .never
		updateTitle()

		collectionView.register(TimelineCell.self, forCellWithReuseIdentifier: TimelineCell.reuseIdentifier)

		timelineArticlesManager.articles = [Article]()
		applySnapshot()
	}
}

private extension TimelineCollectionViewController {

	func createDataSource() -> DataSource {
		UICollectionViewDiffableDataSource<TimelineSectionID, TimelineArticleID>(collectionView: collectionView) { collectionView, indexPath, articleID -> UICollectionViewCell? in
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TimelineCell.reuseIdentifier, for: indexPath) as! TimelineCell
			let article = self.timelineArticlesManager[articleID]
			cell.configure(article, showFeedName: false, showIcon: false)
			return cell
		}
	}

	func applySnapshot() {

		var snapshot = NSDiffableDataSourceSnapshot<TimelineSectionID, TimelineArticleID>()

		let oneAndOnlySectionID = 0
		snapshot.appendSections([oneAndOnlySectionID])

		let articleIDs = timelineArticlesManager.articles.map { $0.id }
		snapshot.appendItems(articleIDs, toSection: oneAndOnlySectionID)

		dataSource.apply(snapshot, animatingDifferences: false)
	}

	func updateTitle() {
		if items.count < 0 {
			title = Self.defaultTitle
		} else if items.count == 1 {
			title = items.first?.title ?? Self.defaultTitle
		} else {
			title = Self.multipleItemsTitle
		}
	}

	func updateArticles() {
		if fetchArticlesTask != nil {
			fetchArticlesTask?.cancel()
		}

		// TODO: handle multiple items, handle all types of Item
		guard let item = items.first as? SidebarFeed,
			  let feed = item.feed,
			  let account = feed.account else {
			return
		}

		fetchArticlesTask = Task { @MainActor in
			let fetchType = FetchType.feed(feed)
			let fetchedArticles = try? await account.fetchArticles(fetchType)

			if Task.isCancelled { return }

			let updatedArticles = fetchedArticles ?? Set([Article]())
			timelineArticlesManager.articles = Array(updatedArticles)

			applySnapshot()
		}
	}
}
