# IQStoreKitManager

[![CI Status](https://img.shields.io/travis/hackiftekhar/IQStoreKitManager.svg?style=flat)](https://travis-ci.org/hackiftekhar/IQStoreKitManager)
[![Version](https://img.shields.io/cocoapods/v/IQStoreKitManager.svg?style=flat)](https://cocoapods.org/pods/IQStoreKitManager)
[![License](https://img.shields.io/cocoapods/l/IQStoreKitManager.svg?style=flat)](https://cocoapods.org/pods/IQStoreKitManager)
[![Platform](https://img.shields.io/cocoapods/p/IQStoreKitManager.svg?style=flat)](https://cocoapods.org/pods/IQStoreKitManager)

[![Screenshot](https://raw.githubusercontent.com/hackiftekhar/IQStoreKitManager/master/Screenshot/IQStoreKitManagerScreenshot.png)](https://github.com/hackiftekhar/IQStoreKitManager)

A StoreKit 2 wrapper for iOS that handles product loading, purchases, transaction observation, purchase-status tracking, and optional server-side delivery through a delegate.

## Features

- **StoreKit 2 purchases** — consumables, non-consumables, and subscriptions
- **Automatic transaction observation** — background updates are verified, delivered, and finished
- **Purchase status tracking** — cached snapshots with keychain persistence and change notifications
- **Subscription lifecycle awareness** — active, grace period, billing retry, and upcoming renewal states
- **Promotional offers** — delegate-based offer signature generation
- **Server delivery hook** — validate receipts and unlock entitlements via `StoreKitManagerDelegate`
- **Built-in utilities** — restore purchases, manage subscriptions, offer code redemption, and refund requests
- **Expiry refresh timers** — automatically refreshes status when subscriptions expire or enter grace period

## Requirements

- iOS 15.0+
- Swift 5.7+
- Xcode 14+

## Installation

IQStoreKitManager is available through [CocoaPods](https://cocoapods.org). Add the following to your Podfile:

```ruby
pod 'IQStoreKitManager'
```

Then run `pod install`.

## Quick Start

Configure `StoreKitManager` at launch with your product identifiers. Optionally provide a delegate to handle product delivery and promotional offer signatures.

```swift
import IQStoreKitManager

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        StoreKitManager.shared.configure(
            productIDs: [
                "com.example.monthly",
                "com.example.yearly",
                "com.example.lifetime",
                "com.example.coins"
            ],
            delegate: self
        )

        return true
    }
}
```

Optionally link purchases to a user account:

```swift
StoreKitManager.shared.setAppAccountToken(userUUID)
```

## Making Purchases

Look up a loaded product and purchase it asynchronously. The result is a `PurchaseState` enum.

```swift
import StoreKit
import IQStoreKitManager

func purchaseMonthly() async {
    guard let product = StoreKitManager.shared.product(withID: "com.example.monthly") else {
        return
    }

    let result = await StoreKitManager.shared.purchase(product: product)

    switch result {
    case .success(let transaction):
        print("Purchased: \(transaction.productID)")
    case .restored:
        print("Restored")
    case .pending:
        print("Purchase pending approval")
    case .userCancelled:
        print("User cancelled")
    case .failure(let error):
        print("Purchase failed: \(error)")
    }
}
```

Purchase with a quantity (consumables) or a subscription offer:

```swift
// Consumable with quantity
let result = await StoreKitManager.shared.purchase(product: coinsProduct, quantity: 2)

// Subscription with an introductory or promotional offer
let offers = StoreKitManager.shared.availableSubscriptionOffers(for: subscriptionProduct)
if let offer = offers.first {
    let result = await StoreKitManager.shared.purchase(product: subscriptionProduct, offer: offer)
}
```

Restore previously purchased products:

```swift
let result = await StoreKitManager.shared.restorePurchases()
```

## StoreKitManagerDelegate

Implement `StoreKitManagerDelegate` when you need server-side validation or promotional offer support.

### Product delivery

After a purchase is verified, the manager calls `deliver` with the transaction, renewal info, and base64 App Store receipt. Call `completion(.success(()))` only after your app (or server) has granted the entitlement. Call `completion(.failure(error))` to keep the transaction unfinished.

```swift
extension AppDelegate: StoreKitManagerDelegate {

    func deliver(
        product: Product,
        transaction: Transaction,
        renewalInfo: Product.SubscriptionInfo.RenewalInfo?,
        receiptData: Data,
        appAccountToken: UUID?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Server-less apps can complete immediately
        completion(.success(()))

        // Server-backed apps can validate the receipt first:
        // YourAPI.validate(receipt: receiptData.base64EncodedString(), productID: transaction.productID) { result in
        //     completion(result)
        // }
    }
}
```

The default protocol extension completes delivery with `.success(())` if you do not implement this method.

### Promotional offer signatures

If you purchase with a promotional offer, implement `generateSignature` and return an `OfferSignature` from your server:

```swift
func generateSignature(
    product: Product,
    offerID: String,
    appAccountToken: UUID?,
    completion: @escaping (Result<OfferSignature, Error>) -> Void
) {
    YourAPI.generateOfferSignature(productID: product.id, offerID: offerID) { result in
        switch result {
        case .success(let data):
            do {
                // OfferSignature is Codable — decode the JSON payload from your server
                let signature = try JSONDecoder().decode(OfferSignature.self, from: data)
                completion(.success(signature))
            } catch {
                completion(.failure(error))
            }
        case .failure(let error):
            completion(.failure(error))
        }
    }
}
```

## Checking Purchase Status

`PurchaseStatusManager` maintains a cached snapshot for each configured product. Snapshots are persisted in the keychain and updated when purchases complete, transactions change, or the app returns to the foreground.

### Observe changes

```swift
NotificationCenter.default.addObserver(
    forName: PurchaseStatusManager.purchaseStatusDidChangedNotification,
    object: nil,
    queue: .main
) { _ in
    // Refresh your UI
}
```

### Query status

```swift
let manager = PurchaseStatusManager.shared

// Check if a specific product is active
let isMonthlyActive = manager.isActive(productID: "com.example.monthly")

// Get detailed status for a product
let snapshot: ProductStatus? = manager.snapshot(for: "com.example.monthly")

// Get all currently active plans
let activePlans: [ProductStatus] = manager.activePlans

// Get the coarse-grained status
let status: ActiveStatus = manager.status(productID: "com.example.monthly")
```

### ProductStatus properties

| Property | Description |
|---|---|
| `id` | Product identifier |
| `displayName` | Localized product name |
| `type` | `.consumable`, `.nonConsumable`, `.autoRenewable`, or `.nonRenewable` |
| `status` | `.inactive`, `.active`, `.gracePeriod`, `.billingRetryPeriod`, `.upcoming`, or `.unlocked` |
| `isActive` | Whether the entitlement is currently active |
| `isEligibleForIntroOffer` | Introductory offer eligibility |
| `isFamilyShareable` | Family Sharing support |
| `renewalInfo` | Subscription renewal details (`RenewalStatus`) when applicable |

`RenewalStatus` exposes `willAutoRenew`, `nextRenewalDate`, `expirationDate`, `gracePeriodExpirationDate`, `autoRenewPreference`, `ownershipType`, and `state`.

## Additional APIs

```swift
// Reload products from the App Store
let products = await StoreKitManager.shared.loadProducts(productIDs: ["com.example.monthly"])

// Manually refresh purchase statuses
await StoreKitManager.shared.refreshStatuses()

// Show Apple's subscription management sheet
if let scene = windowScene {
    _ = await StoreKitManager.shared.showManageSubscriptions(in: scene)
}

// Present offer code redemption
StoreKitManager.shared.presentCodeRedemptionSheet()

// Begin a refund request for a product
if let scene = windowScene {
    _ = await StoreKitManager.shared.beginRefundRequest(for: "com.example.monthly", in: scene)
}
```

## Example Project

To run the example app, clone the repository and install dependencies from the `Example` directory:

```bash
cd Example
pod install
open PaywallViewController.xcworkspace
```

The example demonstrates `IQStoreKitManager` together with [IQPaywallUI](https://github.com/hackiftekhar/IQPaywallUI) for a ready-made paywall UI. See `Example/PaywallViewController/PaywallManager.swift` for a full integration with consumable delivery, subscription checks, and delegate implementation.

## Author

Iftekhar Qurashi — hack.iftekhar@gmail.com

## License

IQStoreKitManager is available under the MIT license. See the [LICENSE](LICENSE) file for more information.
