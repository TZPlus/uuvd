// 极简测试底座：本机 CLT 无 XCTest、swift-testing 宏插件损坏，用断言小程序代替
// （scripts/check.sh 跑）。不是假绿灯：每个用例都是真断言，失败 exit(1)
import Foundation
@testable import uuvdlib

// 单线程顺序执行，nonisolated(unsafe) 规避 Swift 6 全局可变检查
nonisolated(unsafe) var passed = 0
nonisolated(unsafe) var failed = 0

func check(_ name: String, _ condition: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if condition {
        passed += 1
    } else {
        failed += 1
        print("❌ \(name)（\(file):\(line)）")
    }
}

func checkEqual<T: Equatable>(_ name: String, _ a: T, _ b: T) {
    check(name + "（\(a) == \(b)）", a == b)
}

let t0 = Date(timeIntervalSince1970: 1_760_000_000)

func signals(overlay: Bool = false, names: [String] = [], capture: Bool? = false) -> UUSignals {
    UUSignals(overlayVisible: overlay,
              controllers: names.isEmpty ? .unrecognized : .shown(names),
              captureActive: capture)
}
