// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "uuvd",
    platforms: [.macOS(.v14)],
    targets: [
        // CGVirtualDisplay 私有 API 的 Objective-C 桥（声明源自 FreeDisplay，MIT）
        .target(name: "CGVirtualDisplayBridge"),
        // 全部逻辑：会话状态机、UU远程 感知、虚拟屏/物理屏拓扑
        .target(name: "uuvdlib", dependencies: ["CGVirtualDisplayBridge"]),
        // 入口：菜单栏 App + 命令行参数
        .executableTarget(name: "uuvd", dependencies: ["uuvdlib"]),
        .testTarget(name: "uuvdlibTests", dependencies: ["uuvdlib"]),
    ]
)
