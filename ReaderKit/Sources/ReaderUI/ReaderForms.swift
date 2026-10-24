import SwiftUI
import ReaderDomain

struct AccountConnectionView: View {
    let session: ReaderSession
    @Environment(\.dismiss) private var dismiss
    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("FreshRSS") {
                    TextField("API-Adresse (https://…/api/greader.php)", text: $server)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("serverURL")
                    TextField("Benutzername", text: $username)
                        .textContentType(.username).autocorrectionDisabled()
                        .accessibilityIdentifier("username")
                    SecureField("API-Passwort", text: $password)
                        .textContentType(.password)
                        .accessibilityIdentifier("apiPassword")
                }
                Section {
                    Text("Aktiviere den API-Zugriff in FreshRSS und verwende das separate API-Passwort. Die Zugangsdaten werden in der Schlüsselbundverwaltung dieses Geräts gespeichert.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
                if working { ProgressView("Verbindung wird hergestellt") }
            }
            .formStyle(.grouped)
            .navigationTitle("FreshRSS verbinden")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() }.disabled(working) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verbinden") {
                        Task {
                            working = true
                            defer { working = false }
                            do {
                                try await session.connect(server: server.trimmingCharacters(in: .whitespacesAndNewlines),
                                                          username: username.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                                password = ""
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }
                    .disabled(working || server.isEmpty || username.isEmpty || password.isEmpty)
                    .accessibilityIdentifier("submitConnection")
                }
            }
        }
        .frame(idealWidth: 500, idealHeight: 440)
    }
}

struct FeedCreationView: View {
    let session: ReaderSession
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var title = ""
    @State private var accountID: UUID?
    @State private var folderID = ""
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Konto", selection: $accountID) {
                    ForEach(session.accounts) { account in Text(account.username).tag(Optional(account.id)) }
                }
                TextField("Feed-Adresse", text: $url).textContentType(.URL).autocorrectionDisabled()
                TextField("Name (optional)", text: $title)
                TextField("Ordnername (optional)", text: $folderID)
                if let error { Text(error).foregroundStyle(.red) }
                if working { ProgressView() }
            }
            .formStyle(.grouped)
            .navigationTitle("Feed hinzufügen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { Task { await add() } }.disabled(url.isEmpty || working)
                }
            }
        }
        .frame(idealWidth: 450, idealHeight: 360)
        .task { accountID = session.accounts.first?.id }
    }

    private func add() async {
        guard let feedURL = URL(string: url), ["https", "http"].contains(feedURL.scheme), feedURL.host != nil,
              let account = session.accounts.first(where: { $0.id == accountID }), let client = session.services.client else {
            error = "Bitte eine gültige Feed-Adresse und ein Konto auswählen."
            return
        }
        working = true
        defer { working = false }
        do {
            try await client.addFeed(account: account, url: feedURL, title: title.isEmpty ? nil : title,
                                     folderID: folderID.isEmpty ? nil : "user/-/label/" + folderID)
            try await client.refresh(account: account)
            session.services.didChange()
            await session.reload()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct FeedSettingsView: View {
    let session: ReaderSession
    let feed: FeedSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var mode: FeedMode
    @State private var cloudAllowed: Bool
    @State private var folderID: String
    @State private var working = false
    @State private var error: String?

    init(session: ReaderSession, feed: FeedSnapshot) {
        self.session = session
        self.feed = feed
        let preferences = session.preferences(for: feed)
        self.title = feed.title
        self.mode = preferences.mode
        self.cloudAllowed = preferences.cloudAllowed
        self.folderID = feed.folderIDs.first ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Feed") {
                    TextField("Name", text: $title)
                    Picker("Ordner", selection: $folderID) {
                        Text("Ohne Ordner").tag("")
                        ForEach(session.folders.filter { $0.accountID == feed.id.accountID }) { folder in
                            Text(folder.title).tag(folder.remoteID)
                        }
                    }
                    if let url = feed.homePageURL { Link("Website öffnen", destination: url) }
                }
                Section("Darstellung auf diesem Gerät") {
                    Picker("Modus", selection: $mode) {
                        Text("Normal").tag(FeedMode.normal)
                        Text("Tagesübersicht").tag(FeedMode.digest)
                    }
                    Text("Eine Tagesübersicht bündelt Beiträge. Alle Originale bleiben im Feed, in der Suche und über die Quellen erreichbar.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Apple Private Cloud Compute erlauben", isOn: $cloudAllowed)
                        .disabled(!session.services.privateCloudComputeConfigured)
                    if !session.services.privateCloudComputeConfigured {
                        Text("Dieser Build ist für lokale KI konfiguriert. PCC benötigt eine gesonderte Apple-Freigabe und ein passendes signiertes Berechtigungsprofil.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Ohne diese Freigabe verarbeitet nur das lokale Apple-Modell die Texte. PCC benötigt eine verfügbare Apple-Berechtigung und ein Kontingent; eine Aktivierung garantiert keine Verfügbarkeit.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error { Text(error).foregroundStyle(.red) }
                if working { ProgressView() }
            }
            .formStyle(.grouped)
            .navigationTitle("Feed-Einstellungen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() }.disabled(working) }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { Task { await save() } }.disabled(working || title.isEmpty) }
            }
        }
        .frame(idealWidth: 500, idealHeight: 540)
    }

    private func save() async {
        working = true
        defer { working = false }
        do {
            if let client = session.services.client, let account = session.accounts.first(where: { $0.id == feed.id.accountID }) {
                if title != feed.title { try await client.renameFeed(account: account, feedID: feed.id.remoteID, title: title) }
                if folderID != (feed.folderIDs.first ?? "") {
                    try await client.moveFeed(account: account, feedID: feed.id.remoteID,
                                              fromFolderID: feed.folderIDs.first, toFolderID: folderID.isEmpty ? nil : folderID)
                }
                if title != feed.title || folderID != (feed.folderIDs.first ?? "") { try await client.refresh(account: account) }
            }
            var preferences = session.preferences(for: feed)
            preferences.mode = mode
            preferences.cloudAllowed = cloudAllowed
            await session.savePreferences(preferences)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct FolderSettingsView: View {
    let session: ReaderSession
    let folder: FolderSnapshot
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var working = false
    @State private var error: String?

    init(session: ReaderSession, folder: FolderSnapshot) {
        self.session = session
        self.folder = folder
        self.title = folder.title
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Ordnername", text: $title)
                if let error { Text(error).foregroundStyle(.red) }
                if working { ProgressView() }
            }
            .formStyle(.grouped)
            .navigationTitle("Ordner umbenennen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() }.disabled(working) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        Task {
                            working = true
                            defer { working = false }
                            do {
                                guard let account = session.accounts.first(where: { $0.id == folder.accountID }),
                                      let client = session.services.client else { return }
                                try await client.renameFolder(account: account, folderID: folder.remoteID, title: title)
                                try await client.refresh(account: account)
                                session.services.didChange()
                                await session.reload()
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }
                    .disabled(working || title.isEmpty)
                }
            }
        }
        .frame(idealWidth: 400, idealHeight: 250)
    }
}
