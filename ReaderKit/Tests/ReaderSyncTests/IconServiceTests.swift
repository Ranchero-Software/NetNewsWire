import Foundation
import Synchronization
import Testing
import ReaderDomain
@testable import ReaderSync

struct IconServiceTests {
    @Test func `Iconkandidaten erhalten relative Pfade und werden pro Homepage gebildet`() throws {
        let base = try #require(URL(string: "https://example.test/news/index"))
        let html = "<link rel='shortcut icon' href='../favicon.png?v=1&amp;s=2'><link rel='stylesheet' href='bad.css'><link rel='ICON' href='https://cdn.test/icon.png'>"
        #expect(IconService.iconCandidates(in: html, relativeTo: base).map(\.absoluteString) == [
            "https://example.test/favicon.png?v=1&s=2", "https://cdn.test/icon.png"
        ])
    }

    @Test func `Homepagefehler verhindert unabhängigen Favicon-Fallback nicht`() async throws {
        let fixture = try IconFixture()
        await fixture.server.setMode(.homepageFailure)
        let icon = try await fixture.service.icon(for: fixture.url("/home"))
        #expect(icon == Data([1, 2, 3]))
        #expect(await fixture.server.paths == ["/home", "/favicon.ico"])
    }

    @Test func `Verschachtelte Homepages behalten unabhängige Ergebnisse und transiente Fehler sind erneut versuchbar`() async throws {
        let fixture = try IconFixture()
        await fixture.server.setMode(.transientA)
        async let a = fixture.service.icon(for: fixture.url("/a"))
        async let b = fixture.service.icon(for: fixture.url("/b"))
        let (firstA, firstB) = try await (a, b)
        #expect(firstA == nil)
        #expect(firstB == Data([2]))
        await fixture.server.setMode(.normal)
        #expect(try await fixture.service.icon(for: fixture.url("/a")) == Data([1]))
        #expect(try await fixture.service.icon(for: fixture.url("/b")) == Data([2]))
        #expect(await fixture.server.paths.filter { $0 == "/a" }.count == 2)
        #expect(await fixture.server.paths.filter { $0 == "/b" }.count == 1)
    }

    @Test func `Falscher Inhaltstyp und übergroße Bildantwort werden verworfen`() async throws {
        let fixture = try IconFixture(maximumBytes: 128)
        await fixture.server.setMode(.wrongType)
        #expect(try await fixture.service.icon(for: fixture.url("/a")) == nil)
        await fixture.server.setMode(.oversized)
        #expect(try await fixture.service.icon(for: fixture.url("/a")) == nil)
    }

    @Test(.timeLimit(.minutes(1))) func `Abbruch des letzten Konsumenten verhindert den Fallback-Request`() async throws {
        let fixture = try IconFixture()
        let gate = IconRequestGate()
        await fixture.server.setGate(gate)
        let request = Task { try await fixture.service.icon(for: fixture.url("/home")) }
        await gate.waitUntilEntered()
        request.cancel()
        await gate.open()
        await #expect(throws: (any Error).self) { try await request.value }
        #expect(await fixture.server.paths == ["/home"])
    }

    @Test(.timeLimit(.minutes(1))) func `Ein einzelner Netzwerkplatz serialisiert vollständige Iconaufträge`() async throws {
        let fixture = try IconFixture(maximumConcurrentRequests: 1)
        let gate = IconRequestGate()
        await fixture.server.setGate(gate)
        let first = Task { try await fixture.service.icon(for: fixture.url("/home")) }
        await gate.waitUntilEntered()
        let second = Task { try await fixture.service.icon(for: fixture.url("/a")) }
        await gate.open()
        _ = try await first.value
        #expect(try await second.value == Data([1]))
        #expect(await fixture.server.paths == ["/home", "/favicon.ico", "/a", "/a.png"])
    }
}

private final class IconFixture: @unchecked Sendable {
    let server = IconTestServer()
    let service: IconService
    private let host: String
    private let session: URLSession
    init(maximumBytes: Int = 1_048_576, maximumConcurrentRequests: Int = 2) throws {
        host = UUID().uuidString.lowercased() + ".test"
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [IconURLProtocol.self]
        session = URLSession(configuration: configuration)
        service = IconService(session: session, maximumConcurrentRequests: maximumConcurrentRequests, maximumBytes: maximumBytes)
        let server = server
        IconURLProtocol.register(host: host) { request in try await server.respond(request) }
    }
    func url(_ path: String) throws -> URL { try #require(URL(string: "https://" + host + path)) }
    deinit { session.invalidateAndCancel(); IconURLProtocol.unregister(host: host) }
}

private actor IconRequestGate {
    private var entered = false
    private var observers: [CheckedContinuation<Void, Never>] = []
    private var blocked: CheckedContinuation<Void, Never>?
    func pause() async {
        entered = true
        observers.forEach { $0.resume() }
        observers.removeAll()
        await withCheckedContinuation { blocked = $0 }
    }
    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func open() { blocked?.resume(); blocked = nil }
}

private struct IconResponse: Sendable {
    let status: Int
    let mime: String
    let data: Data
}

private actor IconTestServer {
    enum Mode { case normal, homepageFailure, transientA, wrongType, oversized }
    private var mode: Mode = .normal
    private var gate: IconRequestGate?
    var paths: [String] = []
    func setMode(_ mode: Mode) { self.mode = mode }
    func setGate(_ gate: IconRequestGate) { self.gate = gate }
    func respond(_ request: URLRequest) async throws -> IconResponse {
        let path = try #require(request.url?.path)
        paths.append(path)
        if path == "/home" {
            if let gate { await gate.pause() }
            return IconResponse(status: 403, mime: "text/html", data: Data())
        }
        if path == "/a" || path == "/b" {
            let candidate = path + ".png"
            return IconResponse(status: 200, mime: "text/html", data: Data("<link rel='icon' href='\(candidate)'>".utf8))
        }
        if path == "/a.png" {
            switch mode {
            case .transientA: return IconResponse(status: 503, mime: "text/plain", data: Data())
            case .wrongType: return IconResponse(status: 200, mime: "text/html", data: Data("<script>bad</script>".utf8))
            case .oversized: return IconResponse(status: 200, mime: "image/png", data: Data(repeating: 0, count: 129))
            default: return IconResponse(status: 200, mime: "image/png", data: Data([1]))
            }
        }
        if path == "/b.png" { return IconResponse(status: 200, mime: "image/png", data: Data([2])) }
        return IconResponse(status: mode == .homepageFailure ? 200 : 404, mime: "image/x-icon", data: Data([1, 2, 3]))
    }
}

private final class IconURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) async throws -> IconResponse
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
                guard let response = HTTPURLResponse(url: url, statusCode: result.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": result.mime, "Content-Length": String(result.data.count)]) else { throw ReaderError.invalidResponse }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: result.data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
        runningTask.withLock { $0 = task }
    }
    override func stopLoading() { runningTask.withLock { $0?.cancel(); $0 = nil } }
}
