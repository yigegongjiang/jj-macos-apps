// swift-tools-version:6.2
import PackageDescription

// SwiftPM executable，无 xcodeproj / Storyboard。产物 .build/<config>/jj-macos-apps 由 package.sh 组装进 .app bundle。
// defaultIsolation(MainActor)：AppKit 全程主线程，消除 Swift 6 并发告警；后台工作显式 hop 到全局队列。
// sqlite3：macOS SDK 内置系统模块，无第三方依赖。
let package = Package(
    name: "jj-macos-apps",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "jj-macos-apps",
            path: "Sources/jj-macos-apps",
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
