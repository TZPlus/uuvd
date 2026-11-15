// UU远程 的身份。各处认 UU（感知、窗口排除）都认这里（源自 Snug，MIT）
import Foundation

public enum UURemote {
    /// UU远程 主程序
    public static let bundleID = "com.netease.uuremote"
    /// 被远程时在本机注入鼠标键盘、推流、放覆盖窗口的进程
    public static let serverProcess = "UURemoteServer"
}
