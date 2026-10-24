import Foundation
import Observation
import ReaderDomain
import ReaderSync
import ReaderContent
import ReaderIntelligence

/// Shared work belongs to the account services; selection and presentation belong to a window.
@MainActor @Observable
public final class ReaderServices {
    public let repository: any ReaderRepository
    public let credentials: (any CredentialStore)?
    public let client: FreshRSSClient?
    public let digests: DigestCoordinator?
    public let content: ArticleContentService?
    public let privateCloudComputeConfigured: Bool
    public private(set) var revision = 0
    @ObservationIgnored private var refreshTask: Task<Void, Error>?
    @ObservationIgnored private var lastSuccessfulRefresh: Date?

    public init(repository: any ReaderRepository, credentials: (any CredentialStore)? = nil,
                client: FreshRSSClient? = nil, digests: DigestCoordinator? = nil, content: ArticleContentService? = nil,
                privateCloudComputeConfigured: Bool = false) {
        self.repository = repository
        self.credentials = credentials
        self.client = client
        self.digests = digests
        self.content = content
        self.privateCloudComputeConfigured = privateCloudComputeConfigured
    }

    public func didChange() { revision &+= 1 }

    /// Window cancellation does not cancel account work shared with another active window.
    public func refreshIfNeeded(force: Bool = false) async throws {
        guard let client else { return }
        if let refreshTask { try await refreshTask.value; return }
        if !force, let lastSuccessfulRefresh, Date().timeIntervalSince(lastSuccessfulRefresh) < 60 { return }
        let repository = repository
        let task = Task {
            for account in try await repository.accounts() { try await client.refresh(account: account) }
        }
        refreshTask = task
        do {
            try await task.value
            lastSuccessfulRefresh = Date()
            refreshTask = nil
            didChange()
        } catch {
            refreshTask = nil
            throw error
        }
    }
}

public enum TimelineSelection: Hashable, Sendable {
    case article(ArticleKey)
    case digest(String)
}

public struct TimelineRow: Identifiable, Hashable, Sendable {
    public var id: TimelineSelection
    public var title: String
    public var subtitle: String
    public var date: Date
    public var unread: Bool
    public var starred: Bool
    public var isDigest: Bool
}
