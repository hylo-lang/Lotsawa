// swift-tools-version: 6.0
import PackageDescription
import Foundation

let CitronParser
  = Target.Dependency.product(name: "CitronParserModule", package: "citron")
let CitronLexer
  = Target.Dependency.product(  name: "CitronLexerModule", package: "citron")

/// Dependencies for documentation extraction.
///
/// Most people don't need to extract documentation; set `LOTSAWA_ENABLE_DOC_GENERATION` in your
/// environment if you do.
let docGenerationDependency: [Package.Dependency] =
  ProcessInfo.processInfo.environment["LOTSAWA_ENABLE_DOC_GENERATION"] != nil
  ? [.package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.3.0")] : []

let thisDirectory = try (#filePath).replacing(Regex(#"[\\/][^\\/]*$"#), with: "")

let package = Package(
  name: "Lotsawa",
    platforms: [
       .macOS(.v15)
    ],
    products: [
        .library(
            name: "Lotsawa",
            targets: ["Lotsawa"]),
        .library(
            name: "LotsawaC",
            targets: ["LotsawaC"]),
        .library(
            name: "LotsawaFrontend",
            targets: ["LotsawaFrontend"])
    ],
    dependencies: [
      .package(url: "https://github.com/dabrahams/citron.git", from: "2.1.7"),
      .package(url: "https://github.com/SwiftPackageIndex/SPIManifest.git", from: "0.12.0")
    ]
      + docGenerationDependency,

    targets: [
        .target(
            name: "Lotsawa",
            dependencies: []),
        .target(
            name: "LotsawaC",
            dependencies: ["Lotsawa"],
            swiftSettings: [
              .unsafeFlags(["-import-objc-header", thisDirectory + "/Sources/LotsawaC/include/LotsawaC.h"])]),
        .target(
            name: "LotsawaFrontend",
            dependencies: ["Lotsawa"]),
        .testTarget(
            name: "LotsawaTests",
            dependencies: ["Lotsawa", CitronParser, CitronLexer, "TestResources"],
            plugins: [ .plugin(name: "CitronParserGenerator", package: "citron") ]),
        .testTarget(
            name: "LotsawaFrontendTests",
            dependencies: ["Lotsawa", "LotsawaFrontend"]),
        .target(
          name: "TestResources",
          dependencies: ["Lotsawa"],
          resources: [
            .copy("AnsiCTokens.txt"),
            .copy("AnsiCGrammar.txt"),
            .copy("AnsiCSymbolIDs.txt"),
          ]
        ),
        .executableTarget(name: "Profile", dependencies: ["Lotsawa", "TestResources"]),
        /*
        .testTarget(
          name: "LotsawaCTests",
          dependencies: ["LotsawaC"]),
        */
    ]
)
