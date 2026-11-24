// swift-tools-version: 6.0
//
//  Test-only package for the Tsakhur keyboard's product layer.
//
//  The keyboard engine lives in the General Keyboard package
//  (../GeneralKeyboard-iOS) and is tested there. This package tests what
//  Tsakhur adds on top: `TsakhurCore` compiles the very same product files
//  that ship inside the TsakhurKeyboardExtension target (the definition,
//  layout, strings and identity), via an explicit `sources:` list, and the
//  tests run them through the real engine: the definition, the layout
//  against the pinned Russian baseline and the measured letter counts, the
//  shipped dictionary artifacts, learning and the typing path.
//
//  Run from the repo root (General Keyboard checked out next to this repo):
//    xcodebuild test -scheme TsakhurCoreTests-Package \
//      -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
//
//  iOS-only by design: the layout and the engine use UIKit types.
//
import PackageDescription

let package = Package(
    name: "TsakhurCoreTests",
    platforms: [.iOS(.v18)],
    dependencies: [
        .package(path: "../GeneralKeyboard-iOS"),
    ],
    targets: [
        .target(
            name: "TsakhurCore",
            dependencies: [.product(name: "GeneralKeyboard", package: "GeneralKeyboard-iOS")],
            path: "TsakhurKeyboard/TsakhurKeyboardExtension",
            sources: [
                "TsakhurDefinition.swift",
                "TsakhurLayout.swift",
                "TsakhurStrings.swift",
                "TsakhurIdentity.swift",
            ]
        ),
        .testTarget(
            name: "TsakhurCoreTests",
            dependencies: ["TsakhurCore", .product(name: "GeneralKeyboard", package: "GeneralKeyboard-iOS")],
            path: "Tests/TsakhurCoreTests",
            // Read through #filePath (like the shipped artifacts), not bundled.
            exclude: ["Fixtures"]
        ),
    ]
)
