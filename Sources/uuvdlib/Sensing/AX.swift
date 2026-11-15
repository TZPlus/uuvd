// 辅助功能接口的薄封装（读 UU 控制端表格用）。
// 超时：App 卡住时辅助功能的每次调用要等满超时，系统默认约 6 秒；把全局超时设成 1 秒（源自 Snug，MIT）
import ApplicationServices
import Foundation

public enum AX {
    /// App 卡住时每次调用最多等这么久
    static let timeout: Float = 1

    public static var isTrusted: Bool { AXIsProcessTrusted() }

    /// 把本进程的全局超时设成 timeout。只对单个对象设只管那一个对象（头文件原话），
    /// 从 App 对象取回的窗口对象照样走系统默认的约 6 秒；启动时调一次
    public static func configureTimeout() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), timeout)
    }

    public static func application(_ pid: pid_t) -> AXUIElement { AXUIElementCreateApplication(pid) }

    public static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    public static func string(_ element: AXUIElement, _ name: String) -> String? { attribute(element, name) as? String }
}
