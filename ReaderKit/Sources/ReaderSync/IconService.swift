import Foundation
import ReaderDomain

/// Coalesces requests per homepage and bounds network concurrency, response sizes and memory.
/// The returned bytes can be decoded by the caller using its own display-scale context.
public actor IconService {
    private struct Job {
        let id: UUID
        let task: Task<Data?, any Error>
        var consumers: Set<UUID>
    }
    private struct Cached { let data: Data; let created: Date }
    private let session: URLSession
    private let permits: IconPermits
    private let maximumBytes: Int
    private var jobs: [URL: Job] = [:]
    private var cache: [URL: Cached] = [:]

    public init(session: URLSession = .shared, maximumConcurrentRequests: Int = 3, maximumBytes: Int = 1_048_576) {
        self.session = session
        self.permits = IconPermits(limit: max(1, maximumConcurrentRequests))
        self.maximumBytes = max(1, maximumBytes)
    }

    public func icon(for homePage: URL) async throws -> Data? {
        try Task.checkCancellation()
        guard let key = Self.normalized(homePage) else { throw ReaderError.invalidURL }
        if let cached = cache[key], Date().timeIntervalSince(cached.created) < 86_400 { return cached.data }
        let consumer = UUID()
        let job: Job
        if var existing = jobs[key] {
            existing.consumers.insert(consumer)
            jobs[key] = existing
            job = existing
        } else {
            let session = session
            let maximumBytes = maximumBytes
            let permits = permits
            let task = Task {
                await permits.acquire()
                do {
                    try Task.checkCancellation()
                    let data = try await Self.load(key, session: session, maximumBytes: maximumBytes)
                    await permits.release()
                    return data
                } catch {
                    await permits.release()
                    throw error
                }
            }
            job = Job(id: UUID(), task: task, consumers: [consumer])
            jobs[key] = job
        }
        return try await withTaskCancellationHandler {
            defer { releaseConsumer(consumer, for: key, jobID: job.id) }
            let data = try await job.task.value
            try Task.checkCancellation()
            if let data {
                if cache.count >= 32, let oldest = cache.min(by: { $0.value.created < $1.value.created })?.key { cache[oldest] = nil }
                cache[key] = Cached(data: data, created: Date())
            }
            return data
        } onCancel: {
            Task { await self.releaseConsumer(consumer, for: key, jobID: job.id) }
        }
    }

    private func releaseConsumer(_ consumer: UUID, for homePage: URL, jobID: UUID) {
        guard var job = jobs[homePage], job.id == jobID else { return }
        job.consumers.remove(consumer)
        if job.consumers.isEmpty {
            job.task.cancel()
            jobs[homePage] = nil
        } else { jobs[homePage] = job }
    }

    private static func normalized(_ url: URL) -> URL? {
        guard ["https", "http"].contains(url.scheme?.lowercased()), url.host != nil,
              url.user == nil, url.password == nil,
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.fragment = nil
        return parts.url
    }

    private static func load(_ homePage: URL, session: URLSession, maximumBytes: Int) async throws -> Data? {
        var candidates: [URL] = []
        do {
            let (data, response) = try await fetch(homePage, session: session, maximumBytes: min(maximumBytes, 524_288), image: false)
            if let html = String(data: data, encoding: .utf8) {
                candidates = iconCandidates(in: html, relativeTo: response.url ?? homePage)
            }
        } catch {
            try Task.checkCancellation()
            // The host-level fallback is independent of homepage download or metadata success.
        }
        if var root = URLComponents(url: homePage, resolvingAgainstBaseURL: false) {
            root.path = "/favicon.ico"
            root.query = nil
            root.fragment = nil
            if let url = root.url, !candidates.contains(url) { candidates.append(url) }
        }
        for candidate in candidates {
            try Task.checkCancellation()
            do {
                let (data, _) = try await fetch(candidate, session: session, maximumBytes: maximumBytes, image: true)
                if !data.isEmpty { return data }
            } catch { try Task.checkCancellation() }
        }
        return nil
    }

    static func iconCandidates(in html: String, relativeTo base: URL) -> [URL] {
        guard let links = try? NSRegularExpression(pattern: "<link\\b[^>]*>", options: [.caseInsensitive]),
              let attributes = try? NSRegularExpression(pattern: "([\\w-]+)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))", options: [.caseInsensitive]) else { return [] }
        var result: [URL] = []
        for match in links.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let range = Range(match.range, in: html) else { continue }
            let link = String(html[range])
            var values: [String: String] = [:]
            for attribute in attributes.matches(in: link, range: NSRange(link.startIndex..., in: link)) {
                guard let name = Range(attribute.range(at: 1), in: link),
                      let value = (2...4).compactMap({ Range(attribute.range(at: $0), in: link) }).first else { continue }
                values[String(link[name]).lowercased()] = String(link[value])
            }
            let rels = Set((values["rel"] ?? "").lowercased().split(whereSeparator: \.isWhitespace).map(String.init))
            guard !rels.isDisjoint(with: ["icon", "apple-touch-icon", "apple-touch-icon-precomposed"]),
                  let href = values["href"]?.replacingOccurrences(of: "&amp;", with: "&"),
                  let url = URL(string: href, relativeTo: base)?.absoluteURL,
                  let normalized = normalized(url), !result.contains(normalized) else { continue }
            result.append(normalized)
        }
        return result
    }

    private static func fetch(_ url: URL, session: URLSession, maximumBytes: Int, image: Bool) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(image ? "image/*" : "text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        defer { bytes.task.cancel() }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ReaderError.invalidResponse }
        let mime = http.mimeType?.lowercased() ?? ""
        guard image ? mime.hasPrefix("image/") : ["text/html", "application/xhtml+xml"].contains(mime) else { throw ReaderError.invalidResponse }
        guard http.expectedContentLength <= maximumBytes else { throw ReaderError.unavailable("Das Icon ist zu groß.") }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < maximumBytes else { throw ReaderError.unavailable("Das Icon ist zu groß.") }
            data.append(byte)
        }
        return (data, http)
    }
}

private actor IconPermits {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    init(limit: Int) { available = limit }
    func acquire() async {
        if available > 0 { available -= 1; return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() {
        if waiters.isEmpty { available += 1 } else { waiters.removeFirst().resume() }
    }
}
