import Foundation
import Testing
@testable import ReaderDomain

struct IdentityTests {
    @Test func `Artikelidentität ist an das Konto gebunden`() {
        #expect(ArticleKey(accountID: UUID(), remoteID: "1") != ArticleKey(accountID: UUID(), remoteID: "1"))
    }
    @Test func `Neue Änderungen haben eigene Bestätigungsidentitäten`() {
        let key = ArticleKey(accountID: UUID(), remoteID: "1")
        #expect(PendingChange(article: key, field: .read, value: true).id != PendingChange(article: key, field: .read, value: false).id)
    }
}
