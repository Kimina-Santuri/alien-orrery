// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Orrery",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Orrery",
            path: "Sources/Orrery",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreMedia"),
            ]
        )
    ]
)
