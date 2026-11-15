// 会话变化 → 查设备配置 → 建屏/撤屏（源自 UUyc-companion 的 Coordinator，MIT，配合 Snug 会话层重写）
import Foundation

public final class Coordinator: @unchecked Sendable {
    public init() {}

    let sensor = UUSensor()
    public let display = DisplayManager()
    private let store = ConfigStore.shared

    /// 状态变化时通知菜单栏刷新
    public var onChange: (() -> Void)?

    private var session = RemoteSession()
    private var timer: Timer?

    /// 调试：模拟连入的控制端名称（不读 UU）
    public var simulatedName: String?

    public var connected: Bool { session.inEpisode || simulatedName != nil }

    public var statusText: String {
        if display.wedged { return "⛔️ 屏幕设置无响应，请重启 Mac" }
        if store.config.paused { return "已暂停：连接时不做调整" }
        guard connected else { return "等待其它设备连接中" }
        let who = session.episodeController ?? "未知设备"
        if let c = display.current, display.isActive {
            return "\(who) 已连接 · 虚拟屏已匹配 \(c.sizeLabel)\(display.physicalOff ? " · 物理屏幕已软关闭" : "")"
        }
        return "\(who) 已连接 · 虚拟屏没有调整"
    }

    public func start() {
        display.shouldDisablePhysical = { [weak self] in
            guard let self else { return false }
            return self.store.config.shouldDisablePhysical && PhysicalDisplays.available
        }
        display.shouldSetMain = { [weak self] in self?.store.config.shouldSetMain ?? false }
        display.recoverIfNeeded()
        sensor.start()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
    }

    /// 测试入口：直接注入一拍信号
    public func update(_ signals: UUSignals, now: Date) {
        for t in session.update(signals, now: now) { handle(t) }
    }

    private func tick() {
        var signals = sensor.sample(now: Date())
        // 调试模拟：覆盖窗口信号置真，让 tracker 走连入路径
        if simulatedName != nil { signals.overlayVisible = true }
        update(signals, now: Date())
    }

    private func handle(_ transition: SessionTransition) {
        switch transition {
        case .began, .resumed:
            onChange?()
            applyController()
        case .controllerChanged(let name):
            Log.info("控制端变为 \(name)")
            onChange?()
            applyController()
        case .interrupted:
            onChange?()
        case .ended:
            display.remove()
            onChange?()
        }
    }

    /// 按当前控制端名字查配置并应用。名字还没读到时不动作（等下一次信号变化或换控制端）
    private func applyController() {
        guard !store.config.paused else { return }
        guard let name = simulatedName ?? session.episodeController else {
            Log.info("控制端名称未读到，等待")
            return
        }
        guard let cfg = store.device(named: name) else {
            if display.isActive { display.remove() }
            Log.info("「\(name)」不在设备列表里，不调整")
            return
        }
        guard cfg.hasSize else {
            if display.isActive { display.remove() }
            Log.info("「\(name)」还没填分辨率，不调整")
            return
        }
        if display.matches(cfg) { return }
        session.noteSelfInducedChange(at: Date())
        display.create(cfg)
        onChange?()
    }

    // MARK: - 菜单操作

    public func setPaused(_ paused: Bool) {
        store.config.paused = paused
        if paused {
            display.remove()
        } else if connected {
            applyController()
        }
        onChange?()
    }

    /// 配置变更后，若正在被控则按新配置重新应用
    public func configChanged() {
        if connected, !store.config.paused { applyController() }
        onChange?()
    }

    /// 快捷键 / 菜单：立即恢复物理屏
    public func restorePhysical() {
        Log.info("手动恢复物理屏")
        display.restorePhysicalNow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.onChange?() }
    }

    public func shutdown(completion: @escaping () -> Void) {
        sensor.stop()
        timer?.invalidate()
        display.remove(completion: completion)
    }
}
