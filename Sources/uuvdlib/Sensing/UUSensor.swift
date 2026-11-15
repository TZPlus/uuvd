// 每拍合成一份对 UU远程 的观测：覆盖窗口（同步查）、控制端表格（后台读）、推流（日志子进程）（源自 Snug，MIT）
import Foundation

final class UUSensor {
    private let controllers = ControllerReader()
    private let captureLog = CaptureLogWatcher()

    func start() { captureLog.start() }
    func stop() { captureLog.stop() }

    /// now 是墙钟：推流日志的时间戳是墙钟
    func sample(now: Date) -> UUSignals {
        let capture = captureLog.sample(at: now)
        return UUSignals(overlayVisible: UURemoteApp.overlayVisible(),
                         controllers: controllers.poll(),
                         captureActive: capture.active)
    }
}
