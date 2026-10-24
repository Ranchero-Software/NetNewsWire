import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import ReaderDomain

public struct OPMLSubscription: Hashable, Sendable {
    public var title: String
    public var url: URL
    public var homePageURL: URL?
    public var folderPath: [String]
    public init(title: String, url: URL, homePageURL: URL? = nil, folderPath: [String] = []) {
        self.title = title; self.url = url; self.homePageURL = homePageURL; self.folderPath = folderPath
    }
}

public enum OPMLDocument {
    public static func parse(_ data: Data) throws -> [OPMLSubscription] {
        guard data.count <= 5_000_000 else { throw ReaderError.invalidResponse }
        let delegate = OPMLDelegate()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.isOPML, !delegate.invalid else { throw ReaderError.invalidResponse }
        return delegate.subscriptions
    }

    public static func export(feeds: [FeedSnapshot], folders: [FolderSnapshot], preferences: [FeedPreferences] = []) -> Data {
        func escape(_ text: String) -> String {
            text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        func outline(_ feed: FeedSnapshot) -> String {
            let home = feed.homePageURL.map { " htmlUrl=\"\(escape($0.absoluteString))\"" } ?? ""
            return "<outline type=\"rss\" text=\"\(escape(feed.title))\" title=\"\(escape(feed.title))\" xmlUrl=\"\(escape(feed.url.absoluteString))\"\(home)/>"
        }
        let tree = ExportNode()
        for feed in feeds.sorted(by: { $0.id.id < $1.id.id }) {
            let importedPath = preferences.first { $0.id == feed.id }?.importedFolderPath ?? []
            let serverPaths = feed.folderIDs.compactMap { id in
                folders.first { $0.accountID == feed.id.accountID && $0.remoteID == id }.map { [$0.title] }
            }
            let paths = !importedPath.isEmpty ? [importedPath] : (serverPaths.isEmpty ? [[]] : serverPaths)
            for path in paths {
                var node = tree
                for component in path {
                    if node.children[component] == nil { node.children[component] = ExportNode() }
                    if let child = node.children[component] { node = child }
                }
                node.feeds.append(feed)
            }
        }
        func render(_ node: ExportNode) -> [String] {
            var result = node.feeds.map(outline)
            for name in node.children.keys.sorted() {
                if let child = node.children[name] {
                    result.append("<outline text=\"\(escape(name))\">")
                    result += render(child)
                    result.append("</outline>")
                }
            }
            return result
        }
        var parts = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?><opml version=\"2.0\"><head><title>Reader</title></head><body>"]
        parts += render(tree)
        parts.append("</body></opml>")
        return Data(parts.joined(separator: "\n").utf8)
    }
}

private final class ExportNode {
    var feeds: [FeedSnapshot] = []
    var children: [String: ExportNode] = [:]
}

private final class OPMLDelegate: NSObject, XMLParserDelegate {
    var subscriptions: [OPMLSubscription] = []
    var isOPML = false
    var invalid = false
    private var depth = 0
    private var outlines: [String?] = []
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if depth == 0 { isOPML = name.lowercased() == "opml" }
        depth += 1
        guard depth < 100 else { invalid = true; parser.abortParsing(); return }
        guard name == "outline" else { return }
        let title = attributes["title"] ?? attributes["text"] ?? ""
        if let raw = attributes["xmlUrl"], let url = URL(string: raw), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            subscriptions.append(OPMLSubscription(title: title, url: url,
                homePageURL: attributes["htmlUrl"].flatMap(URL.init(string:)), folderPath: outlines.compactMap { $0 }))
            outlines.append(nil)
        } else if attributes["xmlUrl"] != nil {
            invalid = true
            outlines.append(nil)
        } else { outlines.append(title) }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        depth -= 1
        if name == "outline", !outlines.isEmpty { outlines.removeLast() }
    }
}
