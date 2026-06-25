//
//  PurchaseStatusManager.swift
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

@objc
public final class PurchaseStatusManager: NSObject {

    @objc public static let shared = PurchaseStatusManager()

    @objc
    public static let purchaseStatusDidChangedNotification: Notification.Name = Notification.Name("PurchaseStatusDidChangedNotification")

    // Cache status snapshots per productID
    private var snapshotStatus: [String: ProductSnapshot] = [:]

    private override init() {
        super.init()
        snapshotStatus = (try? self.cachedSnapshot()) ?? [:]
    }

    @objc public var activePlans: [ProductStatus] {
        let snapshots = self.snapshotStatus.values.filter { $0.isActive }
        return snapshots.map { .init(from: $0) }
    }

    /// Snapshot for UI (active, grace, retry, etc.)
    @objc public func snapshot(for productID: String) -> ProductStatus? {
        guard let snapshot = snapshotStatus[productID] else {
            return nil
        }
        return ProductStatus(from: snapshot)

    }

    @objc public func status(productID: String) -> ActiveStatus {
         return snapshotStatus[productID]?.status ?? .inactive
    }

    @objc public func isActive(productID: String) -> Bool {
         return snapshotStatus[productID]?.isActive == true
    }
}

internal extension PurchaseStatusManager {

    func refreshStatuses(_ products: [Product]) async {
        var newSnapshots: [String: ProductSnapshot] = self.snapshotStatus
        let cachedSnapshots: [String: ProductSnapshot] = (try? self.cachedSnapshot()) ?? [:]
        for product in products {
            if let sub = product.subscription {
                do {
                    let statuses = try await sub.status
                    let snapshot = await self.bestSnapshot(for: product, statuses: statuses)
                    if let snapshot {
                        newSnapshots[product.id] = snapshot
                    } else if let cached = cachedSnapshots[product.id] {
                        newSnapshots[product.id] = cached
                    }
                } catch {

                    if let cached = cachedSnapshots[product.id] {
                        newSnapshots[product.id] = cached
                    } else {
                        // produce a minimal snapshot when status can't be fetched
                        let snap = ProductSnapshot(
                            product: product,
                            isEligibleForIntroOffer: await isEligibleForIntroOffer(for: product),
                            status: nil
                        )
                        newSnapshots[product.id] = snap
                    }
                }
            } else {

                let introEligible = await isEligibleForIntroOffer(for: product)
                // Non-subscription product — try to find a latest transaction
                if let transaction = await StoreKitManager.shared.latestTransaction(for: product.id) {
                    let snap = ProductSnapshot(product: product,
                                               isEligibleForIntroOffer: introEligible,
                                               transaction: transaction)
                    newSnapshots[product.id] = snap
                } else if let cached = cachedSnapshots[product.id] {
                    newSnapshots[product.id] = cached
                } else {
                    // produce a minimal snapshot when status can't be fetched
                    let snap = ProductSnapshot(
                        product: product,
                        isEligibleForIntroOffer: introEligible,
                        status: nil
                    )
                    newSnapshots[product.id] = snap
                }
            }
        }
        self.snapshotStatus = newSnapshots
        if newSnapshots != cachedSnapshots {
//            for pair in newSnapshots {
//                print(pair.key,
//                      pair.value.status.displayName,
//                      "Will Autorenew: \(pair.value.renewalInfo?.willAutoRenew ?? false)",
//                      "Prefs: \(pair.value.renewalInfo?.autoRenewPreference ?? "-"))",
//                      "Renewal: \(pair.value.renewalInfo?.nextRenewalDate?.formatted(date: .numeric, time: .standard) ?? "-"))",
//                      "Expiry: \(pair.value.renewalInfo?.expirationDate?.formatted(date: .numeric, time: .standard) ?? "-")",
//                      "Grace Expiry: \(pair.value.renewalInfo?.gracePeriodExpirationDate?.formatted(date: .numeric, time: .standard) ?? "-")",
//                      separator: "\t"
//                )
//            }
            await MainActor.run {
                NotificationCenter.default.post(name: Self.purchaseStatusDidChangedNotification, object: nil)
            }
        }
        try? persistSnapshot(newSnapshots)

    }

    private func bestSnapshot(for product: Product, statuses: [Product.SubscriptionInfo.Status]) async -> ProductSnapshot? {
        // Prefer currently active-ish states first

        let filtered = statuses.filter {
            (try? $0.renewalInfo.payloadValue.currentProductID) == product.id ||
            (try? $0.renewalInfo.payloadValue.autoRenewPreference) == product.id
        }

        let preferredOrder: [Product.SubscriptionInfo.RenewalState] = [.subscribed, .inGracePeriod, .inBillingRetryPeriod, .expired, .revoked]

        let sorted = filtered.sorted { (lhs: Product.SubscriptionInfo.Status, rhs: Product.SubscriptionInfo.Status) in
            let li = preferredOrder.firstIndex(of: lhs.state) ?? preferredOrder.count
            let ri = preferredOrder.firstIndex(of: rhs.state) ?? preferredOrder.count
            if li != ri { return li < ri }
            // tie-breaker: later expiration date or transaction purchase date

            let lhsVerify = try? StoreKitManager.verify(lhs.transaction)
            let rhsVerify = try? StoreKitManager.verify(rhs.transaction)

            return (lhsVerify?.expirationDate ?? .distantPast) > (rhsVerify?.expirationDate ?? .distantPast)
        }

        let introEligible = await isEligibleForIntroOffer(for: product)

        return ProductSnapshot(
            product: product,
            isEligibleForIntroOffer: introEligible,
            status: sorted.first)
    }

    /// Intro offer eligibility (best available)
    func isEligibleForIntroOffer(for product: Product) async -> Bool {
        if #available(iOS 16.4, *) {
            return await product.subscription?.isEligibleForIntroOffer ?? false
        }
        // Fallback heuristic: if no status for the group, assume eligible
        guard let info = product.subscription else { return false }
        do {
            let statuses = try await info.status
            return statuses.isEmpty
        } catch {
            return false
        }
    }
}
