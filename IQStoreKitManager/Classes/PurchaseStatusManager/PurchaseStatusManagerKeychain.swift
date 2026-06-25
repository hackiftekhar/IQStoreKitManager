//
//  PurchaseStatusManagerKeychain.swift
//  https://github.com/hackiftekhar/IQStoreKitManager
//  Copyright (c) 2025-26 Iftekhar Qurashi.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import Security

internal final class PurchaseStatusManagerKeychain: NSObject {
    private static let access: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    private static let service: String = Bundle.main.bundleIdentifier ?? "com.paywallUI.paywallUI"

    // MARK: - Keychain primitives
    static func set(data: Data, for key: String) throws {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: access
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        if status == errSecSuccess {
            let statusUpdate = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard statusUpdate == errSecSuccess else {
                throw NSError(domain: "\(Self.self)", code: Int(statusUpdate), userInfo: nil)
            }
        } else if status == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { (_, new) in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: "\(Self.self)", code: Int(addStatus), userInfo: nil)
            }
        } else {
            throw NSError(domain: "\(Self.self)", code: Int(status), userInfo: nil)
        }
    }

    static func data(for key: String) throws -> Data {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            guard let data = result as? Data else { throw NSError(domain: "\(Self.self)", code: -1, userInfo: nil) }
            return data
        } else {
            throw NSError(domain: "\(Self.self)", code: Int(status), userInfo: nil)
        }
    }

    static func remove(for key: String) throws {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw NSError(domain: "\(Self.self)", code: Int(status), userInfo: nil)
        }
    }
}
