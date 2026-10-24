import Foundation
import CryptoKit
import ReaderDomain
import ReaderContent

public actor DigestCoordinator {
    private let repository: any ReaderRepository
    private let generator: any SummaryGenerator
    private let extractor: ArticleContentService
    private var running: [FeedKey: Task<[DigestSnapshot], Error>] = [:]

    public init(repository: any ReaderRepository, generator: any SummaryGenerator = AppleSummaryGenerator(),
                extractor: ArticleContentService = ArticleContentService()) {
        self.repository = repository; self.generator = generator; self.extractor = extractor
    }

    public func generate(feed: FeedSnapshot) async throws -> [DigestSnapshot] {
        if let task = running[feed.id] { return try await task.value }
        try Task.checkCancellation()
        let task = Task { try await self.generateDays(feed: feed) }
        running[feed.id] = task
        defer { running[feed.id] = nil }
        // The coordinator owns shared work. Closing one window must not cancel another caller.
        return try await task.value
    }

    public func cancel(feed: FeedKey) { running[feed]?.cancel() }

    public func markRead(_ displayed: DigestSnapshot) async throws {
        // Deliberately use the displayed snapshot, never a freshly loaded digest revision.
        try await repository.setStatus(displayed.sources, field: .read, value: true)
    }

    private func generateDays(feed: FeedSnapshot) async throws -> [DigestSnapshot] {
        let preferences = try await repository.preferences().first { $0.id == feed.id } ?? FeedPreferences(id: feed.id)
        guard preferences.mode == .digest else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: preferences.timeZoneID) ?? .gmt
        var articles: [ArticleSnapshot] = []
        var offset = 0
        while true {
            try Task.checkCancellation()
            let page = try await repository.articles(ArticleQuery(feed: feed.id, offset: offset, limit: 200))
            articles += page
            if page.count < 200 { break }
            offset += page.count
        }
        let days = Dictionary(grouping: articles) { calendar.startOfDay(for: $0.dateArrived) }
        let existing = try await repository.digests()
        var result: [DigestSnapshot] = []
        for day in days.keys.sorted() {
            guard var sources = days[day] else { continue }
            sources.sort { $0.id.id < $1.id.id }
            let sourceFingerprint = try Self.fingerprint(sources)
            let identifier = feed.id.id + "/" + preferences.timeZoneID + "/" + String(Int(day.timeIntervalSince1970))
            if let cached = existing.first(where: { $0.id == identifier }),
               Set(cached.sources) == Set(sources.map(\.id)), cached.warning == nil,
               cached.sourceFingerprint == sourceFingerprint {
                result.append(cached); continue
            }
            var warnings: [String] = []
            for index in sources.indices where sources[index].text.count < 500 {
                try Task.checkCancellation()
                if let url = sources[index].url {
                    do {
                        let expected = sources[index]
                        let full = try await extractor.extract(url: url)
                        guard try await repository.updateContent(expected, html: full.html, text: full.text) else {
                            throw ReaderError.staleResult
                        }
                        sources[index].html = full.html; sources[index].text = full.text
                    } catch is CancellationError { throw CancellationError() } catch ReaderError.staleResult { throw ReaderError.staleResult } catch { warnings.append("Volltext für „\(sources[index].title)“ nicht verfügbar.") }
                }
                if sources[index].text.isEmpty { warnings.append("Nur Titel für „\(sources[index].title)“ verfügbar.") }
            }
            var sections: [DigestSection]
            let repository = repository
            let feedID = feed.id
            do {
                sections = try await generator.summarize(sources, cloudPermission: {
                    let current = try await repository.preferences().first { $0.id == feedID }
                    return current?.mode == .digest && current?.cloudAllowed == true
                })
            } catch is CancellationError { throw CancellationError() } catch { sections = []; warnings.append(error.localizedDescription) }
            let allKeys = Set(sources.map(\.id))
            guard sections.flatMap(\.sources).allSatisfy(allKeys.contains) else { throw ReaderError.invalidResponse }
            let covered = Set(sections.flatMap(\.sources))
            let missing = sources.filter { !covered.contains($0.id) }
            if !missing.isEmpty {
                warnings.append("\(missing.count) Beiträge sind nicht durch KI zusammengefasst und bleiben als Originale erreichbar.")
                sections.append(DigestSection(title: "Weitere Originalbeiträge", text: "",
                                               sources: missing.map(\.id)))
            }
            let digest = DigestSnapshot(id: identifier, feed: feed.id, day: day, timeZoneID: preferences.timeZoneID,
                sections: sections, sources: sources.map(\.id), warning: warnings.isEmpty ? nil : warnings.joined(separator: "\n"),
                sourceFingerprint: try Self.fingerprint(sources))
            try Task.checkCancellation()
            guard try await repository.saveDigest(digest, expectedSources: sources) else { throw ReaderError.staleResult }
            result.append(digest)
        }
        return result
    }

    private static func fingerprint(_ articles: [ArticleSnapshot]) throws -> String {
        struct Source: Encodable { let id: ArticleKey; let title: String; let text: String; let html: String; let url: URL? }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(articles.map { Source(id: $0.id, title: $0.title, text: $0.text, html: $0.html, url: $0.url) })
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
