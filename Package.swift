// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "IQStoreKitManager",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "IQStoreKitManager",
            targets: ["IQStoreKitManager"]
        )
    ],
    targets: [
        .target(name: "IQStoreKitManager",
            path: "IQStoreKitManager",
            resources: [
                .copy("Assets/PrivacyInfo.xcprivacy")
            ],
            linkerSettings: [
                .linkedFramework("StoreKit"),
                .linkedFramework("Foundation"),
                .linkedFramework("Security")
            ]
        )
    ]
)
