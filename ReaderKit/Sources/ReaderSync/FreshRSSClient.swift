import Foundation
import ReaderDomain

/// A FreshRSS-only Google Reader API client. Each account owns one network job at a time,
/// including the suspension points between selecting and acknowledging outbox revisions.
public actor FreshRSSClient {
    private let repository: any ReaderRepository
    private let credentials: any CredentialStore
    private let session: URLSession
    private var authentication: [UUID: String] = [:]
    private var writeTokens: [UUID: String] = [:]
    private var busyAccounts: Set<UUID> = []
    private var waiters: [UUID: [CheckedContinuation<Void, Never>]] = [:]

    public init(repository: any ReaderRepository, credentials: any CredentialStore, session: URLSession = .shared) {
        self.repository = repository
        self.credentials = credentials
        self.session = session
    }

    public func refresh(account: ReaderAccount) async throws {
        await acquire(account.id)
        defer { release(account.id) }
        try Task.checkCancellation()
        try await refreshUnlocked(account)
    }

    public func flush(account: ReaderAccount) async throws {
        await acquire(account.id)
        defer { release(account.id) }
        try Task.checkCancellation()
        try await flushUnlocked(account)
    }

    public func addFeed(account: ReaderAccount, url: URL, title: String? = nil, folderID: String? = nil) async throws {
        _ = try await addSubscription(account: account, url: url, title: title, folderID: folderID)
    }

    @discardableResult
    public func addSubscription(account: ReaderAccount, url: URL, title: String? = nil, folderID: String? = nil) async throws -> FeedKey {
        guard ["https", "http"].contains(url.scheme?.lowercased()), url.host != nil else { throw ReaderError.invalidURL }
        await acquire(account.id)
        defer { release(account.id) }
        try Task.checkCancellation()
        let data = try await write(account, path: "subscription/quickadd", fields: [("quickadd", url.absoluteString), ("output", "json")])
        let result = try JSONDecoder().decode(QuickAdd.self, from: data)
        guard result.numResults > 0, let streamID = result.streamId else {
            throw ReaderError.unavailable("Unter dieser Adresse wurde kein Feed gefunden.")
        }
        var fields = [("ac", "edit"), ("s", streamID)]
        if let title, !title.isEmpty { fields.append(("t", title)) }
        if let folderID { fields.append(("a", folderID)) }
        if fields.count > 2 { try await writeOK(account, path: "subscription/edit", fields: fields) }
        try await refreshUnlocked(account)
        let key = FeedKey(accountID: account.id, remoteID: streamID)
        guard try await repository.feeds().contains(where: { $0.id == key }) else { throw ReaderError.invalidResponse }
        return key
    }

    public func renameFeed(account: ReaderAccount, feedID: String, title: String) async throws {
        try await mutate(account, path: "subscription/edit", fields: [("ac", "edit"), ("s", feedID), ("t", title)])
    }

    public func moveFeed(account: ReaderAccount, feedID: String, fromFolderID: String?, toFolderID: String?) async throws {
        var fields = [("ac", "edit"), ("s", feedID)]
        if let fromFolderID { fields.append(("r", fromFolderID)) }
        if let toFolderID { fields.append(("a", toFolderID)) }
        guard fields.count > 2 else { return }
        try await mutate(account, path: "subscription/edit", fields: fields)
    }

    public func removeFeed(account: ReaderAccount, feedID: String) async throws {
        try await mutate(account, path: "subscription/edit", fields: [("ac", "unsubscribe"), ("s", feedID)])
    }

    public func renameFolder(account: ReaderAccount, folderID: String, title: String) async throws {
        try await mutate(account, path: "rename-tag", fields: [("s", folderID), ("dest", Self.folderID(title))])
    }

    public func removeFolder(account: ReaderAccount, folderID: String) async throws {
        try await mutate(account, path: "disable-tag", fields: [("s", folderID)])
    }

    public func invalidateCredentials(accountID: UUID) {
        authentication[accountID] = nil
        writeTokens[accountID] = nil
    }

    public static func folderID(_ title: String) -> String {
        title.hasPrefix("user/-/label/") ? title : "user/-/label/" + title
    }

    /// Accept the displayed API URL or the FreshRSS installation root, including a subdirectory.
    public static func endpoint(for serverURL: URL) throws -> URL {
        guard ["https", "http"].contains(serverURL.scheme?.lowercased()), serverURL.host != nil,
              serverURL.user == nil, serverURL.password == nil,
              var parts = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else { throw ReaderError.invalidURL }
        parts.query = nil
        parts.fragment = nil
        guard var url = parts.url else { throw ReaderError.invalidURL }
        if url.lastPathComponent != "greader.php" {
            url.append(path: "api/greader.php")
        }
        return url
    }

    private func acquire(_ accountID: UUID) async {
        if busyAccounts.insert(accountID).inserted { return }
        await withCheckedContinuation { continuation in
            waiters[accountID, default: []].append(continuation)
        }
    }

    private func release(_ accountID: UUID) {
        guard var queued = waiters[accountID], !queued.isEmpty else {
            busyAccounts.remove(accountID)
            waiters[accountID] = nil
            return
        }
        let next = queued.removeFirst()
        waiters[accountID] = queued
        next.resume()
    }

    private func mutate(_ account: ReaderAccount, path: String, fields: [(String, String)]) async throws {
        await acquire(account.id)
        defer { release(account.id) }
        try Task.checkCancellation()
        try await writeOK(account, path: path, fields: fields)
        try await refreshUnlocked(account)
    }

    private func refreshUnlocked(_ account: ReaderAccount) async throws {
        try await flushUnlocked(account)
        let subscriptions: Subscriptions = try await decode(account, path: "subscription/list")
        let tags: Tags = try await decode(account, path: "tag/list")
        let allIDs = try await itemIDs(account, stream: "user/-/state/com.google/reading-list")
        let unreadIDs = try await itemIDs(account, stream: "user/-/state/com.google/reading-list", exclude: "user/-/state/com.google/read")
        let starredIDs = try await itemIDs(account, stream: "user/-/state/com.google/starred")
        let ids = Set(allIDs).union(unreadIDs).union(starredIDs).sorted()
        var articles: [ArticleSnapshot] = []
        for start in stride(from: 0, to: ids.count, by: 500) {
            try Task.checkCancellation()
            let batch = Array(ids[start..<min(start + 500, ids.count)])
            let fields = try batch.map { ("i", try ReaderItemID.longForm($0)) } + [("output", "json")]
            let data = try await write(account, path: "stream/items/contents", fields: fields)
            let contents = try JSONDecoder().decode(Contents.self, from: data)
            let converted = try contents.items.map { try $0.snapshot(accountID: account.id) }
            guard Set(batch).isSubset(of: Set(converted.map { $0.id.remoteID })) else {
                throw ReaderError.unavailable("FreshRSS hat nicht alle angeforderten Artikel geliefert. Bitte erneut aktualisieren.")
            }
            articles.append(contentsOf: converted)
        }
        let feeds = try subscriptions.subscriptions.map { item in
            guard let url = URL(string: item.url), ["https", "http"].contains(url.scheme?.lowercased()) else {
                throw ReaderError.invalidResponse
            }
            return FeedSnapshot(id: FeedKey(accountID: account.id, remoteID: item.id), title: item.title, url: url,
                                homePageURL: item.htmlUrl.flatMap(URL.init(string:)), folderIDs: item.categories.map(\.id))
        }
        let folders = tags.tags.filter { $0.id.contains("/label/") }.map {
            FolderSnapshot(accountID: account.id, remoteID: $0.id, title: $0.id.components(separatedBy: "/label/").last ?? $0.id)
        }
        try Task.checkCancellation()
        try await repository.applyRefresh(RefreshSnapshot(accountID: account.id, feeds: feeds, folders: folders,
                                                         articles: articles, unreadIDs: Set(unreadIDs), starredIDs: Set(starredIDs)))
    }

    private func flushUnlocked(_ account: ReaderAccount) async throws {
        let pending = try await repository.pendingChanges(accountID: account.id)
        for field in [StatusField.read, .starred] {
            for value in [false, true] {
                let changes = pending.filter { $0.field == field && $0.value == value }
                for start in stride(from: 0, to: changes.count, by: 500) {
                    let batch = Array(changes[start..<min(start + 500, changes.count)])
                    var fields = try batch.map { ("i", try ReaderItemID.longForm($0.article.remoteID)) }
                    fields.append((value ? "a" : "r", "user/-/state/com.google/" + field.rawValue))
                    try await writeOK(account, path: "edit-tag", fields: fields)
                    try await repository.acknowledge(batch)
                }
            }
        }
    }

    private func itemIDs(_ account: ReaderAccount, stream: String, exclude: String? = nil) async throws -> [String] {
        var result: [String] = []
        var continuation: String?
        var seen: Set<String> = []
        repeat {
            var query = [("s", stream), ("n", "1000"), ("output", "json")]
            if let exclude { query.append(("xt", exclude)) }
            if let continuation { query.append(("c", continuation)) }
            let page: ItemReferences = try await decode(account, path: "stream/items/ids", query: query)
            result.append(contentsOf: try page.itemRefs.map { try ReaderItemID.canonical($0.id) })
            continuation = page.continuation.flatMap { $0.isEmpty ? nil : $0 }
            if let continuation, !seen.insert(continuation).inserted { throw ReaderError.invalidResponse }
        } while continuation != nil
        return result
    }

    private func decode<T: Decodable & Sendable>(_ account: ReaderAccount, path: String, query: [(String, String)] = [("output", "json")]) async throws -> T {
        let data = try await request(account, path: "reader/api/0/" + path, query: query)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func writeOK(_ account: ReaderAccount, path: String, fields: [(String, String)]) async throws {
        let data = try await write(account, path: path, fields: fields)
        guard String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "OK" else {
            throw ReaderError.invalidResponse
        }
    }

    private func write(_ account: ReaderAccount, path: String, fields: [(String, String)]) async throws -> Data {
        for attempt in 0...1 {
            if writeTokens[account.id] == nil {
                let data = try await request(account, path: "reader/api/0/token")
                guard let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
                    throw ReaderError.invalidResponse
                }
                writeTokens[account.id] = token
            }
            guard let token = writeTokens[account.id] else { throw ReaderError.invalidResponse }
            do {
                return try await request(account, path: "reader/api/0/" + path, fields: fields + [("T", token)])
            } catch ReaderError.unauthorized where attempt == 0 {
                writeTokens[account.id] = nil
            }
        }
        throw ReaderError.unauthorized
    }

    private func request(_ account: ReaderAccount, path: String, query: [(String, String)] = [], fields: [(String, String)]? = nil) async throws -> Data {
        for attempt in 0...1 {
            let auth = try await authenticate(account)
            var request = try Self.makeRequest(base: Self.endpoint(for: account.serverURL), path: path, query: query, fields: fields)
            request.setValue("GoogleLogin auth=" + auth, forHTTPHeaderField: "Authorization")
            do { return try await send(request) } catch ReaderError.unauthorized where attempt == 0 { authentication[account.id] = nil }
        }
        throw ReaderError.unauthorized
    }

    private func authenticate(_ account: ReaderAccount) async throws -> String {
        if let token = authentication[account.id] { return token }
        guard let password = try await credentials.password(accountID: account.id), !password.isEmpty else { throw ReaderError.unauthorized }
        let request = try Self.makeRequest(base: Self.endpoint(for: account.serverURL), path: "accounts/ClientLogin", fields: [("Email", account.username), ("Passwd", password)])
        let data = try await send(request)
        guard let body = String(data: data, encoding: .utf8) else { throw ReaderError.invalidResponse }
        let token = body.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return parts.count == 2 && parts[0] == "Auth" ? String(parts[1]) : nil
        }.first
        guard let token, !token.isEmpty else { throw ReaderError.unauthorized }
        authentication[account.id] = token
        return token
    }

    private func send(_ request: URLRequest) async throws -> Data {
        try Task.checkCancellation()
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReaderError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return data
        case 401, 403: throw ReaderError.unauthorized
        default: throw ReaderError.server(http.statusCode)
        }
    }

    private static func makeRequest(base: URL, path: String, query: [(String, String)] = [], fields: [(String, String)]? = nil) throws -> URLRequest {
        guard var parts = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false) else { throw ReaderError.invalidURL }
        if !query.isEmpty { parts.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) } }
        guard let url = parts.url else { throw ReaderError.invalidURL }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let fields {
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(Self.form(fields).utf8)
        }
        return request
    }

    static func form(_ fields: [(String, String)]) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return fields.map { key, value in
            (key.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") + "=" + (value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")
        }.joined(separator: "&")
    }
}

enum ReaderItemID {
    static func canonical(_ value: String) throws -> String {
        if value.hasPrefix("tag:google.com,2005:reader/item/"), let hex = value.split(separator: "/").last, let number = UInt64(hex, radix: 16) {
            return String(Int64(bitPattern: number))
        }
        if let number = Int64(value) { return String(number) }
        if let number = UInt64(value) { return String(Int64(bitPattern: number)) }
        throw ReaderError.invalidResponse
    }

    static func longForm(_ value: String) throws -> String {
        let canonical = try canonical(value)
        guard let number = Int64(canonical) else { throw ReaderError.invalidResponse }
        let hex = String(UInt64(bitPattern: number), radix: 16)
        return "tag:google.com,2005:reader/item/" + String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }
}

private struct Subscriptions: Decodable, Sendable { let subscriptions: [Subscription] }
private struct Subscription: Decodable, Sendable {
    let id: String
    let title: String
    let url: String
    let htmlUrl: String?
    let categories: [Category]
}
private struct Category: Decodable, Sendable { let id: String }
private struct Tags: Decodable, Sendable { let tags: [Tag] }
private struct Tag: Decodable, Sendable { let id: String }
private struct ItemReferences: Decodable, Sendable {
    let itemRefs: [Reference]
    let continuation: String?
}
private struct Reference: Decodable, Sendable { let id: String }
private struct Contents: Decodable, Sendable { let items: [Entry] }
private struct QuickAdd: Decodable, Sendable { let numResults: Int; let streamId: String? }
private struct Entry: Decodable, Sendable {
    struct Summary: Decodable, Sendable { let content: String? }
    struct Alternate: Decodable, Sendable { let href: String }
    struct Origin: Decodable, Sendable { let streamId: String }
    let id: String
    let title: String?
    let summary: Summary?
    let alternate: [Alternate]?
    let origin: Origin
    let published: Double?
    let crawlTimeMsec: String?
    let timestampUsec: String?

    func snapshot(accountID: UUID) throws -> ArticleSnapshot {
        let html = summary?.content ?? ""
        let timestamp = crawlTimeMsec.flatMap(Double.init).map { $0 / 1000 }
            ?? timestampUsec.flatMap(Double.init).map { $0 / 1_000_000 }
        return ArticleSnapshot(id: ArticleKey(accountID: accountID, remoteID: try ReaderItemID.canonical(id)),
                               feedID: origin.streamId, title: Self.plainText(title ?? "Ohne Titel"), html: html, text: Self.plainText(html),
                               url: alternate?.first.flatMap { URL(string: $0.href) }, datePublished: published.map(Date.init(timeIntervalSince1970:)),
                               dateArrived: timestamp.map(Date.init(timeIntervalSince1970:)) ?? Date())
    }

    private static func plainText(_ html: String) -> String {
        let withoutScripts = html.replacingOccurrences(of: "(?is)<(script|style)\\b[^>]*>.*?</\\1>", with: " ", options: .regularExpression)
        var text = withoutScripts.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (entity, character) in [("&nbsp;", " "), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
