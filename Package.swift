// swift-tools-version:6.0
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
        // 本机只有 CLT、无 Xcode：XCTest 模块缺失，CLT 的 swift-testing 宏插件损坏（malformed response），
        // 两个测试框架都不可用。用一个断言式小程序代替，scripts/check.sh 里跑
        .executableTarget(name: "uuvdtests", dependencies: ["uuvdlib"], path: "Tests/uuvdlibTests"),
        // 显示诊断：--list 只读列表 / --touch 空事务健康检查 / 建屏停留释放验证
        .executableTarget(name: "uuvdprobe", dependencies: ["CGVirtualDisplayBridge"]),
    ]
)
