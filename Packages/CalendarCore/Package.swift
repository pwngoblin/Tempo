// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CalendarCore",
    platforms: [.macOS(.v14), .iOS(.v17), .watchOS(.v10)],
    products: [.library(name: "CalendarCore", targets: ["CalendarCore"])],
    targets: [
        .target(name: "CalendarCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "CalendarCoreTests", dependencies: ["CalendarCore"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
