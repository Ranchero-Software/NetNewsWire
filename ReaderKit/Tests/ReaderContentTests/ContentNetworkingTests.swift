import Foundation
import Synchronization
import Testing
import ReaderContent
import ReaderDomain

struct ContentNetworkingTests {
    @Test func `HTTP 403 bleibt ein sichtbarer Volltextfehler`() async throws {
        let fixture = try ContentNetworkFixture()
        await fixture.server.setResponse(status: 403, data: Data("Zugriff verweigert".utf8))
        await #expect(throws: ReaderError.server(403)) { try await fixture.service.extract(url: fixture.url) }
        #expect(await fixture.server.requestCount == 1)
    }

    @Test func `Netzwerktimeout wird an den Aufrufer weitergegeben`() async throws {
        let fixture = try ContentNetworkFixture()
        await fixture.server.setTimeout()
        let error = await #expect(throws: URLError.self) { try await fixture.service.extract(url: fixture.url) }
        #expect(error?.code == .timedOut)
        #expect(await fixture.server.requestCount == 1)
    }

    @Test func `Dieselbe URL liefert nach Inhaltsänderung die neue Version`() async throws {
        let fixture = try ContentNetworkFixture()
        await fixture.server.setResponse(status: 200, data: Self.article(marker: "Erste Angebotsversion"))
        let first = try await fixture.service.extract(url: fixture.url)
        await fixture.server.setResponse(status: 200, data: Self.article(marker: "Aktualisierte Angebotsversion"))
        let second = try await fixture.service.extract(url: fixture.url)
        #expect(first.text.contains("Erste Angebotsversion"))
        #expect(second.text.contains("Aktualisierte Angebotsversion"))
        #expect(!second.text.contains("Erste Angebotsversion"))
        #expect(first != second)
        #expect(await fixture.server.requestCount == 2)
    }

    @Test func `Nachgeladener Volltext löst relative Links gegen die Dokumentadresse auf`() async throws {
        let fixture = try ContentNetworkFixture()
        await fixture.server.setResponse(status: 200, data: Self.article(marker: "Österreichische Angebote"))
        let result = try await fixture.service.extract(url: fixture.url)
        let expectedLink = try #require(URL(string: "/angebote/reader", relativeTo: fixture.url)?.absoluteURL.absoluteString)
        #expect(result.html.contains(expectedLink))
        #expect(result.text.contains("Zum Angebot"))
    }

    @Test func `Übergroße HTML-Antwort wird vor der Extraktion abgelehnt`() async throws {
        let fixture = try ContentNetworkFixture()
        await fixture.server.setResponse(status: 200, data: Data(repeating: 120, count: 4_000_001))
        await #expect(throws: ReaderError.invalidResponse) { try await fixture.service.extract(url: fixture.url) }
        #expect(await fixture.server.requestCount == 1)
    }

    private static func article(marker: String) -> Data {
        let text = String(repeating: "\(marker): Frische Äpfel beim Händler kosten heute 2,99 €. ", count: 50)
        return Data("<html><head><title>\(marker)</title></head><body><article><h1>\(marker)</h1><p>\(text)</p><p><a href='/angebote/reader'>Zum Angebot</a></p></article></body></html>".utf8)
    }
}

private final class ContentNetworkFixture: @unchecked Sendable {
    let server = ContentScriptServer()
    let service: ArticleContentService
    let url: URL
    private let host: String
    private let session: URLSession

    init() throws {
        host = UUID().uuidString.lowercased() + ".test"
        url = try #require(URL(string: "https://" + host + "/2026/10/beitrag"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ContentScriptURLProtocol.self]
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
        service = ArticleContentService(session: session)
        let server = server
        ContentScriptURLProtocol.register(host: host) { request in try await server.respond(request) }
    }

    deinit {
        session.invalidateAndCancel()
        ContentScriptURLProtocol.unregister(host: host)
    }
}

private struct ContentScriptResponse: Sendable {
    let status: Int
    let data: Data
}

private actor ContentScriptServer {
    private var response = ContentScriptResponse(status: 200, data: Data())
    private var timeout = false
    var requestCount = 0

    func setResponse(status: Int, data: Data) {
        response = ContentScriptResponse(status: status, data: data)
        timeout = false
    }

    func setTimeout() { timeout = true }

    func respond(_ request: URLRequest) throws -> ContentScriptResponse {
        requestCount += 1
        if timeout { throw URLError(.timedOut) }
        return response
    }
}

private final class ContentScriptURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> ContentScriptResponse
    private static let handlers = Mutex<[String: Handler]>([:])
    private let runningTask = Mutex<Task<Void, Never>?>(nil)

    static func register(host: String, handler: @escaping Handler) { handlers.withLock { $0[host] = handler } }
    static func unregister(host: String) { handlers.withLock { $0[host] = nil } }
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler = Self.handlers.withLock { $0[request.url?.host ?? ""] }
        let request = request
        let task = Task {
            do {
                guard let handler, let url = request.url else { throw ReaderError.invalidResponse }
                let result = try await handler(request)
                try Task.checkCancellation()
                guard let response = HTTPURLResponse(url: url, statusCode: result.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "text/html; charset=utf-8", "Content-Length": String(result.data.count)]) else {
                    throw ReaderError.invalidResponse
                }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: result.data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
        runningTask.withLock { $0 = task }
    }

    override func stopLoading() { runningTask.withLock { $0?.cancel(); $0 = nil } }
}
