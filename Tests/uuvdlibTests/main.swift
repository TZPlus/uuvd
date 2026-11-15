// 测试入口：跑全部用例，失败 exit(1)
import Foundation
@testable import uuvdlib

testConnectionTracker()
testRemoteSession()
testControllerTable()
testCaptureLogParser()
testCaptureSessionState()

// 稳定序列号：同配置跨进程稳定（FNV-1a，不用随机加盐的 Hasher）
let a = DeviceConfig(name: "iPad Pro", width: 2388, height: 1668)
check("稳定序列号确定性", DisplayManager.stableSerial(for: a) == DisplayManager.stableSerial(for: a))
check("稳定序列号非零", DisplayManager.stableSerial(for: a) != 0)
check("不同配置不同序列号", DisplayManager.stableSerial(for: a) != DisplayManager.stableSerial(for: DeviceConfig(name: "iPad Pro", width: 2388, height: 1668, hiDPI: false)))

print("—— 单测：\(passed) 通过，\(failed) 失败")
exit(failed == 0 ? 0 : 1)
