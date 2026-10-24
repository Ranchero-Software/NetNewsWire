import SwiftUI
import WebKit
import ReaderDomain

struct ReaderDetail: View {
    var session: ReaderSession

    var body: some View {
        VStack(spacing: 0) {
            if let article = session.selectedArticle {
                ArticleDetailView(session: session, article: article)
                    .id(article.id)
            } else if let digest = session.selectedDigest {
                DigestDetailView(session: session, digest: digest)
                    .id(digest.revision)
            } else {
                ContentUnavailableView("Artikel auswählen", systemImage: "newspaper",
                                       description: Text("Normale Artikel und Tagesübersichten bleiben gemeinsam erreichbar."))
            }
        }
        .task(id: session.selection) { await session.loadSelectedArticle() }
    }
}

private struct ArticleDetailView: View {
    var session: ReaderSession
    let article: ArticleSnapshot
    @State private var page = makeArticlePage()
    @State private var extracting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(article.title).font(.title2.bold()).textSelection(.enabled)
                HStack {
                    Button(article.read ? "Als ungelesen" : "Als gelesen", systemImage: article.read ? "envelope.badge" : "checkmark.circle") {
                        Task { await session.setStatus([article.id], field: .read, value: !article.read) }
                    }
                    Button(article.starred ? "Stern entfernen" : "Markieren", systemImage: article.starred ? "star.fill" : "star") {
                        Task { await session.setStatus([article.id], field: .starred, value: !article.starred) }
                    }
                    if let url = article.url { Link("Original", destination: url) }
                    Menu("Artikel", systemImage: "ellipsis") {
                        Button("Volltext laden", systemImage: "doc.text.magnifyingglass") {
                            Task {
                                extracting = true
                                defer { extracting = false }
                                await session.extract(article)
                            }
                        }
                        .disabled(extracting || article.url == nil)
                    }
                    if extracting { ProgressView().controlSize(.small) }
                }
                .buttonStyle(.borderless)
                .font(.callout)
            }
            .padding()
            Divider()
            WebView(page)
                .task(id: article.html + article.text) { await loadHTML() }
        }
    }

    private func loadHTML() async {
        let content = article.html.isEmpty ? "<pre>\(escape(article.text))</pre>" : article.html
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: data:; style-src 'unsafe-inline'; media-src https:;">
        <style>:root{color-scheme:light dark}body{font:17px -apple-system;line-height:1.6;max-width:48rem;margin:auto;padding:1.2rem;overflow-wrap:anywhere}img,video{max-width:100%;height:auto}pre{white-space:pre-wrap}a{color:LinkText}</style>
        </head><body>\(content)</body></html>
        """
        do {
            for try await _ in page.load(html: html, baseURL: article.url ?? URL(fileURLWithPath: "/")) { }
        } catch is CancellationError {
        } catch { session.errorMessage = error.localizedDescription }
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
}

@MainActor
private func makeArticlePage() -> WebPage {
    var configuration = WebPage.Configuration()
    configuration.defaultNavigationPreferences.allowsContentJavaScript = false
    return WebPage(configuration: configuration)
}

private struct DigestDetailView: View {
    var session: ReaderSession
    let digest: DigestSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Tagesübersicht", systemImage: "sparkles").font(.largeTitle.bold())
                Text(digest.day, format: .dateTime.weekday().day().month().year()).foregroundStyle(.secondary)
                Text("KI-Zusammenfassung · \(digest.sources.count) Originalbeiträge")
                    .font(.callout).foregroundStyle(.secondary)
                if let newest = session.digests.first(where: { $0.id == digest.id }), newest.revision != digest.revision {
                    Button("Aktualisierte Übersicht öffnen", systemImage: "arrow.clockwise") { session.openLatestDigest() }
                }
                if let warning = digest.warning {
                    Label(warning, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                Button("Übersicht gelesen", systemImage: "checkmark.circle") {
                    Task { await session.setStatus(digest.sources, field: .read, value: true) }
                }
                .buttonStyle(.borderedProminent)
                Text("Markiert nur die Originale dieser Version. Neue Beiträge bleiben ungelesen.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(digest.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title).font(.title3.bold())
                        Text(section.text).textSelection(.enabled)
                        ForEach(section.sources) { source in
                            if let article = session.sourceArticles.first(where: { $0.id == source }) {
                                sourceButton(article)
                            }
                        }
                    }
                }
                Divider()
                Text("Alle Originalbeiträge").font(.title3.bold())
                if session.loadingSources { ProgressView("Quellen werden geladen") }
                ForEach(session.sourceArticles) { article in sourceButton(article) }
                if !session.loadingSources && session.sourceArticles.count < digest.sources.count {
                    Label("Einige Originale sind lokal nicht mehr verfügbar.", systemImage: "exclamationmark.triangle")
                }
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .task(id: digest.revision) { await session.loadSources(digest) }
    }

    private func sourceButton(_ article: ArticleSnapshot) -> some View {
        Button { session.selection = .article(article.id) } label: {
            Label(article.title, systemImage: article.read ? "doc.text" : "circle")
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.borderless)
    }
}
