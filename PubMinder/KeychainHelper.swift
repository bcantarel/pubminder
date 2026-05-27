//
//  KeychainHelper.swift
//  PubMinder
//
//  Lightweight wrapper around the iOS Keychain for storing sensitive strings
//  (API keys, credentials). Prefer this over UserDefaults for anything secret —
//  Keychain data is encrypted at rest and excluded from iCloud backups by default.
//

import Foundation
import Security

enum KeychainHelper {

    // MARK: - Core operations

    /// Saves `value` to the Keychain under `key`. Overwrites any existing entry.
    /// Returns `true` on success.
    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Delete any existing item first so SecItemAdd doesn't hit errSecDuplicateItem.
        delete(forKey: key)

        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecAttrAccessible:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData:        data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("KeychainHelper: save failed for '\(key)' — OSStatus \(status)")
        }
        return status == errSecSuccess
    }

    /// Returns the string stored under `key`, or `nil` if not found.
    static func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deletes the Keychain entry for `key`. Returns `true` if deleted or not found.
    @discardableResult
    static func delete(forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Migration helper

    /// One-time migration: moves a plain-text value from UserDefaults into the Keychain,
    /// then removes it from UserDefaults so it isn't left lying around in plaintext.
    /// Safe to call on every launch — does nothing if the Keychain already has a value.
    static func migrateFromUserDefaults(userDefaultsKey: String, keychainKey: String) {
        // Already in Keychain — nothing to migrate.
        guard load(forKey: keychainKey) == nil else { return }

        if let legacy = UserDefaults.standard.string(forKey: userDefaultsKey),
           !legacy.isEmpty {
            if save(legacy, forKey: keychainKey) {
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                print("KeychainHelper: migrated '\(userDefaultsKey)' from UserDefaults to Keychain.")
            }
        }
    }
}
