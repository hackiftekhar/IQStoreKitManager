//
//  PurchaseStatusManager+Cache.swift
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

internal extension PurchaseStatusManager {

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let snapshotsAccount = "cached_snapshots"

    func persistSnapshot(_ snapshots: [String: ProductSnapshot]) throws {

        let data = try Self.encoder.encode(snapshots)
        try PurchaseStatusManagerKeychain.set(data: data, for: Self.snapshotsAccount)
    }

    func cachedSnapshot() throws -> [String: ProductSnapshot] {

        guard let data = try? PurchaseStatusManagerKeychain.data(for: Self.snapshotsAccount) else { return [:] }
        let map = try Self.decoder.decode([String: ProductSnapshot].self, from: data)
        return map
    }

    func clearSnapshots() throws {
        try PurchaseStatusManagerKeychain.remove(for: Self.snapshotsAccount)
    }
}
