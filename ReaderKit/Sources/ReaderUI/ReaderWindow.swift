import SwiftUI
import UniformTypeIdentifiers
import ReaderDomain
import ReaderContent
import ReaderSync

public struct ReaderWindow: View {
    private let services: ReaderServices
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: ReaderSession
    @State private var editedFeed: FeedSnapshot?
    @State private var feedToRemove: FeedSnapshot?
    @State private var editedFolder: FolderSnapshot?
    @State private var folderToRemove: FolderSnapshot?
    @State private var addingFeed = false
    @State private var importingOPML = false
    @State private var exportingOPML = false
    @State private var exportDocument = ReaderOPMLFile(data: Data())

    public init(services: ReaderServices) {
        self.services = services
        self.session = ReaderSession(services: services)
    }

    public var body: some View {
        @Bindable var session = session
        NavigationSplitView {
            ReaderSidebar(session: session, edit: { editedFeed = $0 }, remove: { feedToRemove = $0 },
                          editFolder: { editedFolder = $0 }, removeFolder: { folderToRemove = $0 })
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } content: {
            ReaderTimeline(session: session)
                .navigationSplitViewColumnWidth(min: 280, ideal: 360, max: 520)
        } detail: {
            ReaderDetail(session: session)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup {
                Button("Aktualisieren", systemImage: "arrow.clockwise") { Task { await session.refresh() } }
                    .disabled(session.syncing || session.accounts.isEmpty)
                    .keyboardShortcut("r", modifiers: .command)
                    .accessibilityIdentifier("refresh")
                if session.syncing || session.generating { ProgressView().controlSize(.small) }
            }
            .visibilityPriority(.high)
            ToolbarItemGroup {
                Menu("Reader", systemImage: "ellipsis.circle") {
                    Button("FreshRSS-Konto verbinden", systemImage: "person.badge.plus") { session.showingAccount = true }
                    Button("Feed hinzufügen", systemImage: "plus") { addingFeed = true }
                        .disabled(session.accounts.isEmpty)
                    Divider()
                    Button("OPML importieren", systemImage: "square.and.arrow.down") { importingOPML = true }
                        .disabled(session.accounts.isEmpty)
                    Button("OPML exportieren", systemImage: "square.and.arrow.up") { exportOPML() }
                }
            }
        }
        .task(id: session.queryIdentity) { await session.reload(resetLimit: true) }
        .task(id: scenePhase) {
            if scenePhase == .active { await session.activate() }
        }
        .task { await session.observeChanges() }
        .sheet(isPresented: $session.showingAccount) { AccountConnectionView(session: session) }
        .sheet(isPresented: $addingFeed) { FeedCreationView(session: session) }
        .sheet(item: $editedFeed) { feed in FeedSettingsView(session: session, feed: feed) }
        .sheet(item: $editedFolder) { folder in FolderSettingsView(session: session, folder: folder) }
        .confirmationDialog("Feed abbestellen?", item: $feedToRemove) { feed in
            Button("Abbestellen", role: .destructive) {
                Task {
                    await session.runMutation {
                        guard let account = session.accounts.first(where: { $0.id == feed.id.accountID }),
                              let client = services.client else { return }
                        try await client.removeFeed(account: account, feedID: feed.id.remoteID)
                        try await client.refresh(account: account)
                    }
                }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { feed in Text("\(feed.title) wird in FreshRSS abbestellt. Bereits gespeicherte Sterne bleiben erhalten.") }
        .confirmationDialog("Ordner entfernen?", item: $folderToRemove) { folder in
            Button("Ordner entfernen", role: .destructive) {
                Task {
                    await session.runMutation {
                        guard let account = session.accounts.first(where: { $0.id == folder.accountID }),
                              let client = services.client else { return }
                        try await client.removeFolder(account: account, folderID: folder.remoteID)
                        try await client.refresh(account: account)
                    }
                }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { folder in Text("Die Ordnerzuordnung „\(folder.title)“ wird in FreshRSS entfernt.") }
        .alert("Reader", item: $session.errorMessage) { _ in Button("OK", role: .cancel) { } } message: { Text($0) }
        .fileImporter(isPresented: $importingOPML, allowedContentTypes: [.xml, .data]) { result in
            switch result {
            case .success(let url): Task { await importOPML(url) }
            case .failure(let error): session.errorMessage = error.localizedDescription
            }
        }
        .fileExporter(isPresented: $exportingOPML, document: exportDocument, contentType: .xml, defaultFilename: "Feeds.opml") { result in
            if case .failure(let error) = result { session.errorMessage = error.localizedDescription }
        }
    }

    private func exportOPML() {
        exportDocument = ReaderOPMLFile(data: OPMLDocument.export(feeds: session.feeds, folders: session.folders,
                                                                 preferences: session.feedPreferences))
        exportingOPML = true
    }

    private func importOPML(_ url: URL) async {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        await session.runMutation {
            guard let account = session.accounts.first, let client = services.client else { return }
            let data = try await Task.detached { try Data(contentsOf: url) }.value
            let importer = OPMLImportService(repository: services.repository, client: client)
            _ = try await importer.importDocument(data, account: account)
        }
    }
}

private struct ReaderSidebar: View {
    @Bindable var session: ReaderSession
    var edit: (FeedSnapshot) -> Void
    var remove: (FeedSnapshot) -> Void
    var editFolder: (FolderSnapshot) -> Void
    var removeFolder: (FolderSnapshot) -> Void

    var body: some View {
        List(selection: $session.sidebarSelection) {
            Section("Bibliothek") {
                NavigationLink("Ungelesen", value: "unread").tag("unread")
                NavigationLink("Alle Artikel", value: "all").tag("all")
                NavigationLink("Markiert", value: "starred").tag("starred")
            }
            ForEach(session.accounts) { account in
                Section(account.name + " · " + account.username) {
                    ForEach(session.feeds.filter { $0.id.accountID == account.id && $0.folderIDs.isEmpty }) { feed in
                        feedRow(feed)
                    }
                    ForEach(session.folders.filter { $0.accountID == account.id }) { folder in
                        DisclosureGroup {
                            ForEach(session.feeds.filter { $0.id.accountID == account.id && $0.folderIDs.contains(folder.remoteID) }) { feed in
                                feedRow(feed)
                            }
                        } label: {
                            NavigationLink(value: folder.id) { Label(folder.title, systemImage: "folder") }
                        }
                        .tag(folder.id)
                        .contextMenu {
                            Button("Ordner umbenennen", systemImage: "pencil") { editFolder(folder) }
                            Button("Ordner entfernen", systemImage: "folder.badge.minus", role: .destructive) { removeFolder(folder) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Reader")
        .overlay {
            if session.accounts.isEmpty && !session.loading {
                ContentUnavailableView {
                    Label("Deine Feeds", systemImage: "dot.radiowaves.up.forward")
                } description: {
                    Text("Verbinde FreshRSS, um deine Feeds auf diesem Gerät zu lesen.")
                } actions: {
                    Button("FreshRSS verbinden") { session.showingAccount = true }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("connectFreshRSS")
                }
            }
        }
    }

    private func feedRow(_ feed: FeedSnapshot) -> some View {
        NavigationLink(value: feed.id.id) {
            Label(feed.title, systemImage: session.preferences(for: feed).mode == .digest ? "sparkles" : "dot.radiowaves.up.forward")
        }
            .tag(feed.id.id)
            .contextMenu {
                Button("Feed-Einstellungen", systemImage: "slider.horizontal.3") { edit(feed) }
                Button("Abbestellen", systemImage: "minus.circle", role: .destructive) { remove(feed) }
            }
    }
}

private struct ReaderTimeline: View {
    @Bindable var session: ReaderSession

    var body: some View {
        List(selection: $session.selection) {
            ForEach(session.rows) { row in
                NavigationLink(value: row.id) {
                    TimelineRowView(title: row.title, subtitle: row.subtitle, unread: row.unread,
                                    starred: row.starred, isDigest: row.isDigest, date: row.date)
                }
                    .tag(row.id)
            }
            if session.canLoadMore {
                Button("Weitere Artikel laden") { Task { await session.loadMore() } }
                    .disabled(session.loading)
            }
        }
        .navigationTitle(session.title)
        .searchable(text: $session.search, prompt: "Titel und Artikeltext suchen")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("\(session.rows.count) Einträge · \(session.articles.count) geladene Originale")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if session.loading { ProgressView().controlSize(.small) }
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(.bar)
        }
        .overlay {
            if session.rows.isEmpty && !session.loading {
                ContentUnavailableView(session.search.isEmpty ? "Keine Einträge" : "Keine Treffer",
                                       systemImage: session.search.isEmpty ? "tray" : "magnifyingglass")
            }
        }
    }
}

private struct TimelineRowView: View {
    let title: String
    let subtitle: String
    let unread: Bool
    let starred: Bool
    let isDigest: Bool
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                if unread { Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(.tint).accessibilityLabel("Ungelesen") }
                if isDigest { Image(systemName: "sparkles").foregroundStyle(.tint) }
                Text(title).font(.headline).lineLimit(3)
                if starred { Image(systemName: "star.fill").foregroundStyle(.yellow).accessibilityLabel("Markiert") }
            }
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            Text(date, format: .dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
    }
}

struct ReaderOPMLFile: FileDocument {
    static let readableContentTypes: [UTType] = [.xml]
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
