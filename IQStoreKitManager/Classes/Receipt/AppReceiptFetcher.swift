//
//  AppReceiptFetcher.swift
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
import StoreKit

internal final class AppReceiptFetcher: NSObject, SKRequestDelegate {
    enum ReceiptError: Error {
        case missingAfterRefresh
        case refreshFailed(String)
    }

    private var continuations: [NSObject:CheckedContinuation<Void, Error>] = [:]

    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    func fetchBase64Receipt() async throws -> Data {
        if let base64 = readBase64Receipt() {
            return base64
        }
        try await refreshReceipt()
        guard let base64 = readBase64Receipt() else {
            throw ReceiptError.missingAfterRefresh
        }
        return base64
    }

    private func readBase64Receipt() -> Data? {
        guard let url = Bundle.main.appStoreReceiptURL,
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return data
    }

    func refreshReceipt() async throws {

        startBackgroundTask()

        let request = SKReceiptRefreshRequest()
        request.delegate = self
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuations[request] = continuation
            request.start()
        }
    }

    // MARK: SKRequestDelegate

    func requestDidFinish(_ request: SKRequest) {
        self.continuations[request]?.resume(returning: ())
        self.continuations[request] = nil
        endBackgroundTask()
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        self.continuations[request]?.resume(throwing: ReceiptError.refreshFailed(error.localizedDescription))
        self.continuations[request] = nil
        endBackgroundTask()
    }

    private func startBackgroundTask() {
        // 2. BEGIN the Background Task
        self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "SKReceiptRefresh") {
            // Expiration Handler: This is called if the time runs out before the task finishes.
            // You should try to end the task here and clean up.
            self.endBackgroundTask()
            // Optionally, handle the timeout error here if necessary.
        }
    }

    private func endBackgroundTask() {
        if self.backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
            self.backgroundTaskID = .invalid
        }
    }
}
