//
//  File.swift
//  
//
//  Created by Brent Simmons on 3/10/24.
//

import Foundation
import FMDB
import Database
import Articles
import Parser

final class ArticlesTable {

	let name = DatabaseTableName.articles

	private let accountID: String
	private let retentionStyle: ArticlesDatabase.RetentionStyle
	private var articlesCache = [String: Article]()
	private let statusesTable = StatusesTable()
	private let authorsTable = AuthorsTable()
	private let searchTable = SearchTable()

	private lazy var authorsLookupTable: DatabaseLookupTable = {
		DatabaseLookupTable(name: DatabaseTableName.authorsLookup, objectIDKey: DatabaseKey.articleID, relatedObjectIDKey: DatabaseKey.authorID, relatedTable: authorsTable, relationshipName: RelationshipName.authors)
	}()

	// TODO: update articleCutoffDate as time passes and based on user preferences.
	private let articleCutoffDate = Date().bySubtracting(days: 90)

	private typealias ArticlesFetchMethod = (FMDatabase) -> Set<Article>

	init(accountID: String, retentionStyle: ArticlesDatabase.RetentionStyle) {

		self.accountID = accountID
		self.retentionStyle = retentionStyle
	}

	// MARK: - Fetching Articles

	func articles(feedID: String, database: FMDatabase) -> Set<Article> {

		fetchArticlesWithWhereClause(database, whereClause: "articles.feedID = ?", parameters: [feedID as AnyObject])
	}

	func articles(feedIDs: Set<String>, database: FMDatabase) -> Set<Article> {

		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and read=0

		if feedIDs.isEmpty {
			return Set<Article>()
		}

		let parameters = feedIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let whereClause = "feedID in \(placeholders)"

		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func articles(articleIDs: Set<String>, database: FMDatabase) -> Set<Article> {

		if articleIDs.isEmpty {
			return Set<Article>()
		}

		let parameters = articleIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(articleIDs.count))!
		let whereClause = "articleID in \(placeholders)"

		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func unreadArticles(feedIDs: Set<String>, limit: Int?, database: FMDatabase) -> Set<Article> {

		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and read=0

		if feedIDs.isEmpty {
			return Set<Article>()
		}
		let parameters = feedIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		var whereClause = "feedID in \(placeholders) and read=0"
		if let limit = limit {
			whereClause.append(" order by coalesce(datePublished, dateModified, dateArrived) desc limit \(limit)")
		}

		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func todayArticles(feedIDs: Set<String>, cutoffDate: Date, limit: Int?, database: FMDatabase) -> Set<Article> {

		fetchArticlesSince(feedIDs: feedIDs, cutoffDate: cutoffDate, limit: limit, database: database)
	}

	func starredArticles(feedIDs: Set<String>, limit: Int?, database: FMDatabase) -> Set<Article> {

		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and starred=1;

		if feedIDs.isEmpty {
			return Set<Article>()
		}

		let parameters = feedIDs.map { $0 as AnyObject }
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		var whereClause = "feedID in \(placeholders) and starred=1"
		if let limit = limit {
			whereClause.append(" order by coalesce(datePublished, dateModified, dateArrived) desc limit \(limit)")
		}

		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func articlesMatching(searchString: String, feedIDs: Set<String>, database: FMDatabase) -> Set<Article> {

		let articles = fetchArticlesMatching(searchString, database)

		// TODO: include the feedIDs in the SQL rather than filtering here.
		return articles.filter{ feedIDs.contains($0.feedID) }
	}

	func articlesMatching(searchString: String, articleIDs: Set<String>, database: FMDatabase) -> Set<Article> {

		let articles = fetchArticlesMatching(searchString, database)

		// TODO: include the articleIDs in the SQL rather than filtering here.
		return articles.filter{ articleIDs.contains($0.articleID) }
	}

	// MARK: - Unread Counts

	func allUnreadCounts(database: FMDatabase) -> UnreadCountDictionary {

		var unreadCountDictionary = UnreadCountDictionary()

		let sql = "select distinct feedID, count(*) from articles natural join statuses where read=0 group by feedID;"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return unreadCountDictionary
		}

		while resultSet.next() {
			let unreadCount = resultSet.long(forColumnIndex: 1)
			if let feedID = resultSet.string(forColumnIndex: 0) {
				unreadCountDictionary[feedID] = unreadCount
			}
		}
		resultSet.close()

		return unreadCountDictionary
	}

	func unreadCount(feedID: String, database: FMDatabase) -> Int? {

		let sql = "select count(*) from articles natural join statuses where feedID=? and read=0;"
		let unreadCount = database.count(sql: sql, parameters: [feedID], tableName: name)
		return unreadCount
	}

	// Unread count for starred articles in feedIDs.
	func starredAndUnreadCount(feedIDs: Set<String>, database: FMDatabase) -> Int? {

		if feedIDs.isEmpty {
			return 0
		}

		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let sql = "select count(*) from articles natural join statuses where feedID in \(placeholders) and read=0 and starred=1;"
		let parameters = Array(feedIDs) as [Any]

		let unreadCount = database.count(sql: sql, parameters: parameters, tableName: name)
		return unreadCount
	}

	func unreadCounts(feedIDs: Set<String>, database: FMDatabase) -> UnreadCountDictionary {

		var unreadCountDictionary = UnreadCountDictionary()

		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let sql = "select distinct feedID, count(*) from articles natural join statuses where feedID in \(placeholders) and read=0 group by feedID;"

		let parameters = Array(feedIDs) as [Any]

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
			return unreadCountDictionary
		}

		while resultSet.next() {
			let unreadCount = resultSet.long(forColumnIndex: 1)
			if let feedID = resultSet.string(forColumnIndex: 0) {
				unreadCountDictionary[feedID] = unreadCount
			}
		}
		resultSet.close()

		return unreadCountDictionary
	}

	func unreadCount(feedIDs: Set<String>, since: Date, database: FMDatabase) -> Int? {

		if feedIDs.isEmpty {
			return 0
		}

		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let sql = "select count(*) from articles natural join statuses where feedID in \(placeholders) and (datePublished > ? or (datePublished is null and dateArrived > ?)) and read=0;"

		var parameters = [Any]()
		parameters += Array(feedIDs) as [Any]
		parameters += [since] as [Any]
		parameters += [since] as [Any]

		let unreadCount = database.count(sql: sql, parameters: parameters, tableName: name)
		return unreadCount
	}

	// MARK: - Saving, Updating, and Deleting Articles

	/// Update articles and save new ones — for feed-based systems (local and iCloud).
	func update(parsedItems: Set<ParsedItem>, feedID: String, deleteOlder: Bool, database: FMDatabase) -> ArticleChanges {

		precondition(retentionStyle == .feedBased)

		if parsedItems.isEmpty {
			return ArticleChanges()
		}

		// 1. Ensure statuses for all the incoming articles.
		// 2. Create incoming articles with parsedItems.
		// 3. [Deleted - this step is no longer needed]
		// 4. Fetch all articles for the feed.
		// 5. Create array of Articles not in database and save them.
		// 6. Create array of updated Articles and save what’s changed.
		// 7. Call back with new and updated Articles.
		// 8. Delete Articles in database no longer present in the feed.
		// 9. Update search index.

		let articleIDs = parsedItems.articleIDs()

		let (statusesDictionary, _) = statusesTable.ensureStatusesForArticleIDs(articleIDs, false, database) //1
		assert(statusesDictionary.count == articleIDs.count)

		let incomingArticles = Article.articlesWithParsedItems(parsedItems, feedID, accountID, statusesDictionary) //2
		if incomingArticles.isEmpty {
			return ArticleChanges()
		}

		let fetchedArticles = articles(feedID: feedID, database: database) //4
		let fetchedArticlesDictionary = fetchedArticles.dictionary()

		let newArticles = findAndSaveNewArticles(incomingArticles, fetchedArticlesDictionary, database) //5
		let updatedArticles = findAndSaveUpdatedArticles(incomingArticles, fetchedArticlesDictionary, database) //6

		// Articles to delete are 1) not starred and 2) older than 30 days and 3) no longer in feed.
		let articlesToDelete: Set<Article>
		if deleteOlder {
			let cutoffDate = Date().bySubtracting(days: 30)
			articlesToDelete = fetchedArticles.filter { (article) -> Bool in
				return !article.status.starred && article.status.dateArrived < cutoffDate && !articleIDs.contains(article.articleID)
			}
		} else {
			articlesToDelete = Set<Article>()
		}

		addArticlesToCache(newArticles)
		addArticlesToCache(updatedArticles)

		// 8. Delete articles no longer in feed.
		let articleIDsToDelete = articlesToDelete.articleIDs()
		if !articleIDsToDelete.isEmpty {
			removeArticles(articleIDsToDelete, database)
			removeArticleIDsFromCache(articleIDsToDelete)
		}

		// 9. Update search index.
		if let newArticles = newArticles {
			searchTable.indexNewArticles(newArticles, database)
		}
		if let updatedArticles = updatedArticles {
			searchTable.indexUpdatedArticles(updatedArticles, database)
		}

		let articleChanges = ArticleChanges(newArticles: newArticles, updatedArticles: updatedArticles, deletedArticles: articlesToDelete)
		return articleChanges
	}

	/// Update articles and save new ones — for sync systems (Feedbin, Feedly, etc.).
	func update(feedIDsAndItems: [String: Set<ParsedItem>], read: Bool, database: FMDatabase) -> ArticleChanges {

		precondition(retentionStyle == .syncSystem)

		if feedIDsAndItems.isEmpty {
			return ArticleChanges()
		}

		// 1. Ensure statuses for all the incoming articles.
		// 2. Create incoming articles with parsedItems.
		// 3. Ignore incoming articles that are (!starred and read and really old)
		// 4. Fetch all articles for the feed.
		// 5. Create array of Articles not in database and save them.
		// 6. Create array of updated Articles and save what’s changed.
		// 7. Call back with new and updated Articles.
		// 8. Update search index.

		var articleIDs = Set<String>()
		for (_, parsedItems) in feedIDsAndItems {
			articleIDs.formUnion(parsedItems.articleIDs())
		}

		let (statusesDictionary, _) = statusesTable.ensureStatusesForArticleIDs(articleIDs, read, database) //1
		assert(statusesDictionary.count == articleIDs.count)

		let allIncomingArticles = Article.articlesWithFeedIDsAndItems(feedIDsAndItems, accountID, statusesDictionary) //2
		if allIncomingArticles.isEmpty {
			return ArticleChanges()
		}

		let incomingArticles = filterIncomingArticles(allIncomingArticles) //3
		if incomingArticles.isEmpty {
			return ArticleChanges()
		}

		let incomingArticleIDs = incomingArticles.articleIDs()
		let fetchedArticles = articles(articleIDs: incomingArticleIDs, database: database) //4
		let fetchedArticlesDictionary = fetchedArticles.dictionary()

		let newArticles = findAndSaveNewArticles(incomingArticles, fetchedArticlesDictionary, database) //5
		let updatedArticles = findAndSaveUpdatedArticles(incomingArticles, fetchedArticlesDictionary, database) //6

		addArticlesToCache(newArticles)
		addArticlesToCache(updatedArticles)

		// 8. Update search index.
		if let newArticles = newArticles {
			searchTable.indexNewArticles(newArticles, database)
		}
		if let updatedArticles = updatedArticles {
			searchTable.indexUpdatedArticles(updatedArticles, database)
		}

		let articleChanges = ArticleChanges(newArticles: newArticles, updatedArticles: updatedArticles, deletedArticles: nil)
		return articleChanges
	}

	/// Delete articles
	func delete(articleIDs: Set<String>, database: FMDatabase) {

		database.deleteRowsWhere(key: DatabaseKey.articleID, equalsAnyValue: Array(articleIDs), tableName: name)
	}

	// MARK: - Status

	/// Fetch the articleIDs of unread articles.
	func unreadArticleIDs(database: FMDatabase) -> Set<String>? {

		statusesTable.articleIDs(key: .read, value: false, database: database)
	}

	func starredArticleIDs(database: FMDatabase) -> Set<String>? {

		statusesTable.articleIDs(key: .starred, value: true, database: database)
	}

	func articleIDsForStatusesWithoutArticlesNewerThanCutoffDate(database: FMDatabase) -> Set<String>? {

		statusesTable.articleIDsForStatusesWithoutArticlesNewerThan(cutoffDate: articleCutoffDate, database: database)
	}

	func mark(articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool, database: FMDatabase) -> Set<ArticleStatus>? {

		let statuses = statusesTable.mark(articles.statuses(), statusKey, flag, database)
		return statuses
	}

	func mark(articleIDs: Set<String>, statusKey: ArticleStatus.Key, flag: Bool, database: FMDatabase) {

		statusesTable.mark(articleIDs, statusKey, flag, database)
	}

	/// Create statuses for specified articleIDs. For existing statuses, don’t do anything.
	/// For newly-created statuses, mark them as read and not-starred.
	func createStatusesIfNeeded(articleIDs: Set<String>, database: FMDatabase) {

		statusesTable.ensureStatusesForArticleIDs(articleIDs, true, database)
	}

	// MARK: - Indexing

	/// Returns true if it indexed >0 articles. Keep calling until it returns false.
	func indexUnindexedArticles(database: FMDatabase) -> Bool {

		let sql = "select articleID from articles where searchRowID is null limit 500;"
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: nil) else {
			return false
		}
		let articleIDs = resultSet.mapToSet{ $0.string(forColumn: DatabaseKey.articleID) }
		if articleIDs.isEmpty {
			return false
		}

		searchTable.ensureIndexedArticles(articleIDs: articleIDs, database: database)
		return true
	}

	// MARK: - Caches

	func emptyCaches() {

		articlesCache = [String: Article]()
	}

	// MARK: - Cleanup

	/// Delete articles that we won’t show in the UI any longer
	/// — their arrival date is before our 90-day recency window;
	/// they are read; they are not starred.
	///
	/// Because deleting articles might block the database for too long,
	/// we do this in a careful way: delete articles older than a year,
	/// check to see how much time has passed, then decide whether or not to continue.
	/// Repeat for successively more-recent dates.
	func deleteOldArticles(database: FMDatabase) {

		precondition(retentionStyle == .syncSystem)

		func deleteOldArticles(cutoffDate: Date) {
			let sql = "delete from articles where articleID in (select articleID from articles natural join statuses where dateArrived<? and read=1 and starred=0);"
			let parameters = [cutoffDate] as [Any]
			database.executeUpdateInTransaction(sql, withArgumentsIn: parameters)
		}

		let startTime = Date()
		func tooMuchTimeHasPassed() -> Bool {
			let timeElapsed = Date().timeIntervalSince(startTime)
			return timeElapsed > 2.0
		}

		let dayIntervals = [365, 300, 225, 150]
		for dayInterval in dayIntervals {
			deleteOldArticles(cutoffDate: startTime.bySubtracting(days: dayInterval))
			if tooMuchTimeHasPassed() {
				return
			}
		}

		deleteOldArticles(cutoffDate: self.articleCutoffDate)
	}

	func deleteArticlesNotInSubscribedToFeedIDs(_ feedIDs: Set<String>, database: FMDatabase) {

		if feedIDs.isEmpty {
			return
		}

		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!
		let sql = "select articleID from articles where feedID not in \(placeholders);"
		let parameters = Array(feedIDs) as [Any]
		guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
			return
		}
		
		let articleIDs = resultSet.mapToSet{ $0.string(forColumn: DatabaseKey.articleID) }
		if articleIDs.isEmpty {
			return
		}

		removeArticles(articleIDs, database)
		statusesTable.removeStatuses(articleIDs, database)
	}

	func deleteOldStatuses(database: FMDatabase) {

		let sql: String
		let cutoffDate: Date

		switch self.retentionStyle {
		case .syncSystem:
			sql = "delete from statuses where dateArrived<? and read=1 and starred=0 and articleID not in (select articleID from articles);"
			cutoffDate = Date().bySubtracting(days: 180)
		case .feedBased:
			sql = "delete from statuses where dateArrived<? and starred=0 and articleID not in (select articleID from articles);"
			cutoffDate = Date().bySubtracting(days: 30)
		}

		let parameters = [cutoffDate] as [Any]
		database.executeUpdateInTransaction(sql, withArgumentsIn: parameters)
	}
}

private extension ArticlesTable {

	func fetchArticlesWithWhereClause(_ database: FMDatabase, whereClause: String, parameters: [AnyObject]) -> Set<Article> {

		let sql = "select * from articles natural join statuses where \(whereClause);"
		return articlesWithSQL(sql, parameters, database)
	}

	func articlesWithSQL(_ sql: String, _ parameters: [AnyObject], _ database: FMDatabase) -> Set<Article> {

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: parameters) else {
			return Set<Article>()
		}
		return articlesWithResultSet(resultSet, database)
	}

	func articlesWithResultSet(_ resultSet: FMResultSet, _ database: FMDatabase) -> Set<Article> {
		
		var cachedArticles = Set<Article>()
		var fetchedArticles = Set<Article>()

		while resultSet.next() {

			guard let articleID = resultSet.string(forColumn: DatabaseKey.articleID) else {
				assertionFailure("Expected articleID.")
				continue
			}

			if let article = articlesCache[articleID] {
				cachedArticles.insert(article)
				continue
			}

			// The resultSet is a result of a JOIN query with the statuses table,
			// so we can get the statuses at the same time and avoid additional database lookups.
			guard let status = statusesTable.statusWithRow(resultSet, articleID: articleID) else {
				assertionFailure("Expected status.")
				continue
			}

			guard let article = Article(accountID: accountID, row: resultSet, status: status) else {
				continue
			}
			fetchedArticles.insert(article)
		}
		resultSet.close()

		if fetchedArticles.isEmpty {
			return cachedArticles
		}

		// Fetch authors for non-cached articles. (Articles from the cache already have authors.)
		let fetchedArticleIDs = fetchedArticles.articleIDs()
		let authorsMap = authorsLookupTable.fetchRelatedObjects(for: fetchedArticleIDs, in: database)
		let articlesWithFetchedAuthors = fetchedArticles.map { (article) -> Article in
			if let authors = authorsMap?.authors(for: article.articleID) {
				return article.byAdding(authors)
			}
			return article
		}

		// Add fetchedArticles to cache, now that they have attached authors.
		for article in articlesWithFetchedAuthors {
			articlesCache[article.articleID] = article
		}

		return cachedArticles.union(articlesWithFetchedAuthors)
	}

	func fetchArticlesSince(feedIDs: Set<String>, cutoffDate: Date, limit: Int?, database: FMDatabase) -> Set<Article> {
		
		// select * from articles natural join statuses where feedID in ('http://ranchero.com/xml/rss.xml') and (datePublished > ? || (datePublished is null and dateArrived > ?)
		//
		// datePublished may be nil, so we fall back to dateArrived.

		if feedIDs.isEmpty {
			return Set<Article>()
		}

		let parameters = feedIDs.map { $0 as AnyObject } + [cutoffDate as AnyObject, cutoffDate as AnyObject]
		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(feedIDs.count))!

		var whereClause = "feedID in \(placeholders) and (datePublished > ? or (datePublished is null and dateArrived > ?))"
		if let limit = limit {
			whereClause.append(" order by coalesce(datePublished, dateModified, dateArrived) desc limit \(limit)")
		}
		
		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func fetchArticlesMatching(_ searchString: String, _ database: FMDatabase) -> Set<Article> {

		let sql = "select rowid from search where search match ?;"
		let sqlSearchString = sqliteSearchString(with: searchString)
		let searchStringParameters = [sqlSearchString]

		guard let resultSet = database.executeQuery(sql, withArgumentsIn: searchStringParameters) else {
			return Set<Article>()
		}

		let searchRowIDs = resultSet.mapToSet { $0.longLongInt(forColumnIndex: 0) }
		if searchRowIDs.isEmpty {
			return Set<Article>()
		}

		let placeholders = NSString.rs_SQLValueList(withPlaceholders: UInt(searchRowIDs.count))!
		let whereClause = "searchRowID in \(placeholders)"
		let parameters: [AnyObject] = Array(searchRowIDs) as [AnyObject]

		return fetchArticlesWithWhereClause(database, whereClause: whereClause, parameters: parameters)
	}

	func sqliteSearchString(with searchString: String) -> String {
		var s = ""
		searchString.enumerateSubstrings(in: searchString.startIndex..<searchString.endIndex, options: .byWords) { (word, range, enclosingRange, stop) in
			guard let word = word else {
				return
			}
			s += word
			if word != "AND" && word != "OR" {
				s += "*"
			}
			s += " "
		}
		return s
	}

	func removeArticles(_ articleIDs: Set<String>, _ database: FMDatabase) {

		database.deleteRowsWhere(key: DatabaseKey.articleID, equalsAnyValue: Array(articleIDs), tableName: name)
	}

	// MARK: - Cache

	func addArticlesToCache(_ articles: Set<Article>?) {

		guard let articles = articles else {
			return
		}

		for article in articles {
			articlesCache[article.articleID] = article
		}
	}

	func removeArticleIDsFromCache(_ articleIDs: Set<String>) {

		for articleID in articleIDs {
			articlesCache[articleID] = nil
		}
	}

	// MARK: - Saving New Articles

	func findNewArticles(_ incomingArticles: Set<Article>, _ fetchedArticlesDictionary: [String: Article]) -> Set<Article>? {

		let newArticles = Set(incomingArticles.filter { fetchedArticlesDictionary[$0.articleID] == nil })
		return newArticles.isEmpty ? nil : newArticles
	}

	func findAndSaveNewArticles(_ incomingArticles: Set<Article>, _ fetchedArticlesDictionary: [String: Article], _ database: FMDatabase) -> Set<Article>? { //5

		guard let newArticles = findNewArticles(incomingArticles, fetchedArticlesDictionary) else {
			return nil
		}

		saveNewArticles(newArticles, database)
		return newArticles
	}

	func saveNewArticles(_ articles: Set<Article>, _ database: FMDatabase) {
		
		saveRelatedObjectsForNewArticles(articles, database)

		if let databaseDictionaries = articles.databaseDictionaries() {
			database.insertRows(databaseDictionaries, insertType: .orReplace, tableName: name)
		}
	}

	func saveRelatedObjectsForNewArticles(_ articles: Set<Article>, _ database: FMDatabase) {

		let databaseObjects = articles.databaseObjects()
		authorsLookupTable.saveRelatedObjects(for: databaseObjects, in: database)
	}

	// MARK: - Updating Existing Articles

	func articlesWithRelatedObjectChanges<T>(_ comparisonKeyPath: KeyPath<Article, Set<T>?>, _ updatedArticles: Set<Article>, _ fetchedArticles: [String: Article]) -> Set<Article> {
		return updatedArticles.filter{ (updatedArticle) -> Bool in
			if let fetchedArticle = fetchedArticles[updatedArticle.articleID] {
				return updatedArticle[keyPath: comparisonKeyPath] != fetchedArticle[keyPath: comparisonKeyPath]
			}
			assertionFailure("Expected to find matching fetched article.");
			return true
		}
	}

	func updateRelatedObjects<T>(_ comparisonKeyPath: KeyPath<Article, Set<T>?>, _ updatedArticles: Set<Article>, _ fetchedArticles: [String: Article], _ lookupTable: DatabaseLookupTable, _ database: FMDatabase) {

		let articlesWithChanges = articlesWithRelatedObjectChanges(comparisonKeyPath, updatedArticles, fetchedArticles)
		if !articlesWithChanges.isEmpty {
			lookupTable.saveRelatedObjects(for: articlesWithChanges.databaseObjects(), in: database)
		}
	}

	func saveUpdatedRelatedObjects(_ updatedArticles: Set<Article>, _ fetchedArticles: [String: Article], _ database: FMDatabase) {

		updateRelatedObjects(\Article.authors, updatedArticles, fetchedArticles, authorsLookupTable, database)
	}

	func findUpdatedArticles(_ incomingArticles: Set<Article>, _ fetchedArticlesDictionary: [String: Article]) -> Set<Article>? {

		let updatedArticles = incomingArticles.filter{ (incomingArticle) -> Bool in //6
			if let existingArticle = fetchedArticlesDictionary[incomingArticle.articleID] {
				if existingArticle != incomingArticle {
					return true
				}
			}
			return false
		}

		return updatedArticles.isEmpty ? nil : updatedArticles
	}

	func findAndSaveUpdatedArticles(_ incomingArticles: Set<Article>, _ fetchedArticlesDictionary: [String: Article], _ database: FMDatabase) -> Set<Article>? { //6

		guard let updatedArticles = findUpdatedArticles(incomingArticles, fetchedArticlesDictionary) else {
			return nil
		}

		saveUpdatedArticles(Set(updatedArticles), fetchedArticlesDictionary, database)
		return updatedArticles
	}

	func saveUpdatedArticles(_ updatedArticles: Set<Article>, _ fetchedArticles: [String: Article], _ database: FMDatabase) {

		saveUpdatedRelatedObjects(updatedArticles, fetchedArticles, database)

		for updatedArticle in updatedArticles {
			saveUpdatedArticle(updatedArticle, fetchedArticles, database)
		}
	}

	func saveUpdatedArticle(_ updatedArticle: Article, _ fetchedArticles: [String: Article], _ database: FMDatabase) {

		// Only update exactly what has changed in the Article (if anything).
		// Untested theory: this gets us better performance and less database fragmentation.

		guard let fetchedArticle = fetchedArticles[updatedArticle.articleID] else {
			assertionFailure("Expected to find matching fetched article.");
			saveNewArticles(Set([updatedArticle]), database)
			return
		}
		guard let changesDictionary = updatedArticle.changesFrom(fetchedArticle), changesDictionary.count > 0 else {
			// Not unexpected. There may be no changes.
			return
		}

		database.updateRowsWithDictionary(changesDictionary, whereKey: DatabaseKey.articleID, equals: updatedArticle.articleID, tableName: name)
	}

	func articleIsIgnorable(_ article: Article) -> Bool {

		if article.status.starred || !article.status.read {
			return false
		}
		return article.status.dateArrived < articleCutoffDate
	}

	func filterIncomingArticles(_ articles: Set<Article>) -> Set<Article> {

		// Drop Articles that we can ignore.

		precondition(retentionStyle == .syncSystem)

		return Set(articles.filter{ !articleIsIgnorable($0) })
	}
}

private extension Set where Element == ParsedItem {

	func articleIDs() -> Set<String> {

		Set<String>(map { $0.articleID })
	}
}
