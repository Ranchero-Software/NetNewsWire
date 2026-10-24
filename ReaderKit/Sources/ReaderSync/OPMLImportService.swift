import Foundation
import ReaderDomain
import ReaderContent

/// Confirms subscriptions with FreshRSS, then preserves import-only metadata under the confirmed ID.
/// An OPML document is fully validated before its first server mutation.
public actor OPMLImportService {
    private let repository: any ReaderRepository
    private let client: FreshRSSClient
    private var busyAccounts: Set<UUID> = []
    private var waiters: [UUID: [CheckedContinuation<Void, Never>]] = [:]

    public init(repository: any ReaderRepository, client: FreshRSSClient) {
        self.repository = repository
        self.client = client
    }

    public func importDocument(_ data: Data, account: ReaderAccount) async throws -> Int {
        let document = try Self.preflight(OPMLDocument.parse(data))
        await acquire(account.id)
        defer { release(account.id) }
        try Task.checkCancellation()
        for subscription in document {
            try Task.checkCancellation()
            let preferences = try await repository.preferences()
            let feeds = try await repository.feeds().filter { $0.id.accountID == account.id }
            let inputURL = Self.normalizedURL(subscription.url)
            let priorImports = Dictionary(preferences.filter { $0.id.accountID == account.id }.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
            let existing = feeds.first { feed in
                Self.normalizedURL(feed.url) == inputURL || priorImports[feed.id]?.importedFeedURL.map(Self.normalizedURL) == inputURL
            }
            let targetFolder = subscription.folderPath.isEmpty ? nil : FreshRSSClient.folderID(subscription.folderPath.joined(separator: "/"))
            let key: FeedKey
            if let existing {
                key = existing.id
                if let targetFolder, !existing.folderIDs.contains(targetFolder) {
                    try await client.moveFeed(account: account, feedID: key.remoteID,
                                              fromFolderID: existing.folderIDs.first, toFolderID: targetFolder)
                }
            } else {
                key = try await client.addSubscription(account: account, url: subscription.url,
                                                       title: subscription.title.isEmpty ? nil : subscription.title, folderID: targetFolder)
            }
            // The store merges only import fields atomically, preserving concurrent mode/consent edits.
            try await repository.mergeImportMetadata(feed: key, homePageURL: subscription.homePageURL,
                                                       folderPath: subscription.folderPath, feedURL: subscription.url)
        }
        return document.count
    }

    private static func preflight(_ subscriptions: [OPMLSubscription]) throws -> [OPMLSubscription] {
        var orderedURLs: [String] = []
        var unique: [String: OPMLSubscription] = [:]
        for subscription in subscriptions {
            guard ["https", "http"].contains(subscription.url.scheme?.lowercased()), subscription.url.host != nil else {
                throw ReaderError.invalidURL
            }
            guard subscription.folderPath.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw ReaderError.unavailable("Der OPML-Import enthält einen Ordner ohne Namen.")
            }
            if let home = subscription.homePageURL {
                guard ["https", "http"].contains(home.scheme?.lowercased()), home.host != nil else {
                    throw ReaderError.unavailable("Der OPML-Import enthält eine ungültige Homepageadresse.")
                }
            }
            let key = normalizedURL(subscription.url)
            if var prior = unique[key] {
                guard prior.folderPath == subscription.folderPath else {
                    throw ReaderError.unavailable("Ein Feed ist im OPML mehreren unterschiedlichen Ordnerpfaden zugeordnet. FreshRSS unterstützt pro Feed nur eine Kategorie. Bitte die Zuordnung vor dem Import bereinigen.")
                }
                if prior.homePageURL == nil { prior.homePageURL = subscription.homePageURL }
                unique[key] = prior
            } else {
                orderedURLs.append(key)
                unique[key] = subscription
            }
        }
        return orderedURLs.compactMap { unique[$0] }
    }

    private static func normalizedURL(_ url: URL) -> String {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url.absoluteString }
        parts.scheme = parts.scheme?.lowercased()
        parts.host = parts.host?.lowercased()
        parts.fragment = nil
        if (parts.scheme == "https" && parts.port == 443) || (parts.scheme == "http" && parts.port == 80) { parts.port = nil }
        if parts.path.isEmpty { parts.path = "/" }
        return parts.url?.absoluteString ?? url.absoluteString
    }

    private func acquire(_ accountID: UUID) async {
        if busyAccounts.insert(accountID).inserted { return }
        await withCheckedContinuation { waiters[accountID, default: []].append($0) }
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
}
