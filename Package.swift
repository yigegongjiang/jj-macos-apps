// swift-tools-version:6.2
import PackageDescription

// 纯 SwiftPM executable target；无 .xcodeproj / Storyboard / xib。
// 产物 .build/<config>/jj-apps 由 package.sh 组装进 .app bundle。
// defaultIsolation(MainActor)：AppKit App 全程主线程，整 target 默认主 actor，
// 与框架现实一致并消除 Swift 6 并发告警；后台工作（扫描 / knowledgeC 查询）显式 hop 到全局队列。
// SQLite3：macOS SDK 内置系统模块，linkedLibrary 链接 libsqlite3，无第三方依赖。
let package = Package(
    name: "jj-apps",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "jj-apps",
            path: "Sources/jj-apps",
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
