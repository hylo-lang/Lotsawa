// swift-tools-version: 5.6
import PackageDescription

let CitronParser
  = Target.Dependency.product(name: "CitronParserModule", package: "citron")
let CitronLexer
  = Target.Dependency.product(  name: "CitronLexerModule", package: "citron")

let package = Package(
    name: "Lotsawa",
    products: [
        .library(
            name: "Lotsawa",
            targets: ["Lotsawa"]),
    ],
    dependencies: [
      .package(url: "https://github.com/dabrahams/citron.git", from: "2.1.0"),
    ],
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
