// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeclarativeAPI",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "DeclarativeAPI",
            targets: ["DeclarativeAPI"]),
        .executable(name: "Example", targets: ["Example"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-mongo-driver.git", from: "1.0.0"),
        .package(url: "https://github.com/Autimatisering/IkigaJSON.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.0.0-rc.1"),
        .package(url: "https://github.com/OpenKitten/MongoKitten.git", from: "6.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "DeclarativeAPI",
            dependencies: ["Vapor", "IkigaJSON"]),
        .target(
            name: "Example",
            dependencies: ["DeclarativeAPI", "IkigaJSON", "Fluent", "FluentMongoDriver", "JWTKit", "Vapor", "MongoKitten"]),// "Meow"]),
        .testTarget(
            name: "DeclarativeAPITests",
            dependencies: ["DeclarativeAPI", "Vapor", "MongoKitten", "Meow"]),
    ]
)
