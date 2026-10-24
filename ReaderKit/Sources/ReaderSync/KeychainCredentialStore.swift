import Foundation
import Security
import ReaderDomain

/// Blocking Security calls execute on this actor, outside the UI actor. Credentials remain device-local.
public actor KeychainCredentialStore: CredentialStore {
    private let service: String

    public init(service: String = "eu.mpwg.reader.credentials") { self.service = service }

    public func password(accountID: UUID) throws -> String? {
        var query = baseQuery(accountID)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        try check(status)
        guard let data = result as? Data, let password = String(data: data, encoding: .utf8) else { throw ReaderError.invalidResponse }
        return password
    }

    public func savePassword(_ password: String, accountID: UUID) throws {
        try Task.checkCancellation()
        let query = baseQuery(accountID)
        let data = Data(password.utf8)
        let update = [kSecValueData: data] as CFDictionary
        let status = SecItemUpdate(query as CFDictionary, update)
        if status == errSecItemNotFound {
            var addition = query
            addition[kSecValueData] = data
            addition[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addition as CFDictionary, nil)
            if addStatus == errSecDuplicateItem { try check(SecItemUpdate(query as CFDictionary, update)) } else { try check(addStatus) }
        } else { try check(status) }
    }

    public func removePassword(accountID: UUID) throws {
        let status = SecItemDelete(baseQuery(accountID) as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }

    private func baseQuery(_ accountID: UUID) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: accountID.uuidString, kSecAttrSynchronizable: false]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw ReaderError.unavailable("Zugriff auf den Schlüsselbund fehlgeschlagen (\(status)).")
        }
    }
}
