import SwiftUI
import ReaderDomain
import ReaderPersistence
import ReaderSync
import ReaderContent
import ReaderIntelligence
import ReaderUI

@main
struct ReaderApplication: App {
    private let bootstrap: ReaderBootstrap

    init() { bootstrap = ReaderBootstrap() }

    var body: some Scene {
        WindowGroup(id: "reader") {
            if let services = bootstrap.services {
                ReaderWindow(services: services)
            } else {
                ContentUnavailableView("Reader konnte nicht starten", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text(bootstrap.errorMessage ?? "Der lokale Datenspeicher ist nicht verfügbar."))
                    .padding()
            }
        }
        .defaultSize(width: 1200, height: 800)
    }
}

@MainActor
private final class ReaderBootstrap {
    let services: ReaderServices?
    let errorMessage: String?

    init() {
        do {
            let bundleID = Bundle.main.bundleIdentifier ?? "eu.mpwg.reader.debug"
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true).appendingPathComponent(bundleID, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let uiTesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
            let store = try ReaderStore(url: uiTesting ? nil : directory.appendingPathComponent("Reader.store"), inMemory: uiTesting)
            let credentials = KeychainCredentialStore(service: bundleID)
            let client = FreshRSSClient(repository: store, credentials: credentials)
            let content = ArticleContentService()
            let digests = DigestCoordinator(repository: store, generator: AppleSummaryGenerator(), extractor: content)
            services = ReaderServices(repository: store, credentials: credentials, client: client, digests: digests, content: content)
            errorMessage = nil
        } catch {
            services = nil
            errorMessage = error.localizedDescription
        }
    }
}
