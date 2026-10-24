import Foundation
import JavaScriptCore
import ReaderDomain

public struct ExtractedContent: Hashable, Sendable {
    public var html: String
    public var text: String
    public init(html: String, text: String) { self.html = html; self.text = text }
}

/// Runs the vendored Mozilla parser in a private JS context, without executing page scripts.
public actor ArticleContentService {
    private let session: URLSession
    public init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 20
        self.session = session ?? URLSession(configuration: configuration)
    }

    public func extract(url: URL) async throws -> ExtractedContent {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { throw ReaderError.invalidURL }
        let (data, response) = try await session.data(from: url)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw ReaderError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw ReaderError.server(response.statusCode) }
        guard data.count <= 4_000_000,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ReaderError.invalidResponse
        }
        let result = try extract(html: html, baseURL: response.url ?? url)
        return result
    }

    public func extract(html: String, baseURL: URL) throws -> ExtractedContent {
        try Task.checkCancellation()
        guard html.utf8.count <= 4_000_000, let context = JSContext() else { throw ReaderError.invalidResponse }
        // JavaScriptCore has no browser URL constructor. Resolve links with Foundation instead.
        let resolve: @convention(block) (String, String) -> String = { raw, base in
            let url = URL(string: raw, relativeTo: URL(string: base))?.absoluteURL
            return url?.scheme == nil ? "" : (url?.absoluteString ?? "")
        }
        context.setObject(resolve, forKeyedSubscript: "readerResolveURL" as NSString)
        context.evaluateScript("class URL { constructor(raw, base) { this.href = readerResolveURL(String(raw), base ? String(base) : ''); if (!this.href) throw new Error('Invalid URL'); } }")
        for name in ["JSDOMParser", "Readability"] {
            guard let path = Bundle.module.url(forResource: name, withExtension: "js") else {
                throw ReaderError.unavailable("Der lokale Volltextparser fehlt.")
            }
            context.evaluateScript(try String(contentsOf: path, encoding: .utf8))
            guard context.exception == nil else { throw ReaderError.invalidResponse }
        }
        context.setObject(html, forKeyedSubscript: "sourceHTML" as NSString)
        context.setObject(baseURL.absoluteString, forKeyedSubscript: "sourceURL" as NSString)
        let script = """
        (function () {
          const doc = new JSDOMParser().parse(sourceHTML);
          doc.documentURI = sourceURL;
          const parsed = new Readability(doc, {charThreshold: 0, maxElemsToParse: 50000}).parse();
          return parsed ? JSON.stringify({html: parsed.content || '', text: parsed.textContent || ''}) : null;
        })()
        """
        guard let value = context.evaluateScript(script), context.exception == nil,
              let json = value.toString(), let data = json.data(using: .utf8) else { throw ReaderError.invalidResponse }
        struct Result: Decodable { var html: String; var text: String }
        let result = try JSONDecoder().decode(Result.self, from: data)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ReaderError.unavailable("Auf dieser Seite wurde kein Artikeltext gefunden.") }
        try Task.checkCancellation()
        return ExtractedContent(html: result.html, text: text)
    }
}
