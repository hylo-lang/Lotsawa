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

let package = Package(
  name: "Lotsawa",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "Lotsawa",
            targets: ["Lotsawa"]),
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
        .testTarget(
            name: "LotsawaTests",
            dependencies: ["Lotsawa", CitronParser, CitronLexer],
            plugins: [ .plugin(name: "CitronParserGenerator", package: "citron") ]
        ),
    ]
)
