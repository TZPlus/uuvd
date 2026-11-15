// uuvd 入口：菜单栏常驻 App
// 调试：uuvd --simulate "<设备名>" [秒数]   模拟一次连入/断开（不依赖 UU），设备名需在 config.json 里
//      uuvd --dump-controllers             打印当前控制端（AX 读 UU 主窗口）
import AppKit
import Carbon.HIToolbox
import uuvdlib

if CommandLine.arguments.contains("--dump-controllers") {
    guard AX.isTrusted else { print("未获得辅助功能权限"); exit(1) }
    guard let pid = UURemoteApp.pid() else { print("UU远程 没在运行"); exit(1) }
    guard let rows = UUAccessibility.rows(pid: pid) else { print("未读到 UU 窗口"); exit(1) }
    print("控制端：\(ControllerTable(rows: rows).names)")
    exit(0)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = Coordinator()
    private var statusItem: NSStatusItem?
    private var hotKeyRef: EventHotKeyRef?
    private var terminating = false

    func applicationDidFinishLaunching(_ note: Notification) {
        Log.openFile()
        AX.configureTimeout()
        Log.info("启动 uuvd \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")，辅助功能权限：\(AX.isTrusted)")
        if !ConfigStore.shared.isConfigured {
            Log.warn("config.json 里没有可用的设备配置，连上时不会调整。配置路径：\(ConfigStore.dir.path)")
        }
        installStatusBar()
        installHotkey()
        coordinator.onChange = { [weak self] in self?.refreshStatus() }
        coordinator.start()
    }

    private func installStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "uuvd")
        item.menu = NSMenu()
        statusItem = item
        refreshStatus()
    }

    private func refreshStatus() {
        guard let menu = statusItem?.menu else { return }
        menu.removeAllItems()

        let status = NSMenuItem(title: coordinator.statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let pause = NSMenuItem(title: ConfigStore.shared.config.paused ? "恢复自动调整" : "暂停自动调整",
                               action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)

        let restore = NSMenuItem(title: "立即恢复所有屏幕（⌃⌥⌘9）", action: #selector(restorePhysical), keyEquivalent: "")
        restore.target = self
        menu.addItem(restore)

        let openConfig = NSMenuItem(title: "打开配置目录", action: #selector(openConfigDir), keyEquivalent: "")
        openConfig.target = self
        menu.addItem(openConfig)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 uuvd", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func togglePause() {
        coordinator.setPaused(!ConfigStore.shared.config.paused)
    }

    @objc private func restorePhysical() {
        coordinator.restorePhysical()
    }

    @objc private func openConfigDir() {
        NSWorkspace.shared.open(ConfigStore.dir)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// 全局快捷键 ⌃⌥⌘9：立即恢复物理屏（Carbon 热键，无需任何权限）
    private func installHotkey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
            guard let ctx else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { delegate.coordinator.restorePhysical() }
            return noErr
        }, 1, &spec, me, nil)
        let id = EventHotKeyID(signature: OSType(0x5555_5644), id: 1)  // 'UUVD'
        let err = RegisterEventHotKey(UInt32(kVK_ANSI_9), UInt32(cmdKey | optionKey | controlKey), id,
                                      GetApplicationEventTarget(), 0, &hotKeyRef)
        Log.info(err == noErr ? "已注册快捷键 ⌃⌥⌘9" : "⚠️ 快捷键 ⌃⌥⌘9 注册失败 \(err)")
    }

    /// 退出前异步收尾（恢复物理屏、移除虚拟屏、还原布局）。
    /// 注意：.terminateLater 期间主队列的延时任务不会执行，收尾会卡住；
    /// 所以先取消本次退出，收尾完成后再真正退出（最多等 8 秒，残留下次启动时恢复）
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminating { return .terminateNow }
        terminating = true
        var done = false
        let finish = {
            guard !done else { return }
            done = true
            Log.info("退出 uuvd")
            Log.flush()
            NSApp.terminate(nil)
        }
        coordinator.shutdown(completion: finish)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: finish)
        return .terminateCancel
    }
}

// 调试：--simulate "<设备名>" [秒数]
if let i = CommandLine.arguments.firstIndex(of: "--simulate"), i + 1 < CommandLine.arguments.count {
    let name = CommandLine.arguments[i + 1]
    let seconds = i + 2 < CommandLine.arguments.count ? Double(CommandLine.arguments[i + 2]) ?? 10 : 10
    let delegate = MainActor.assumeIsolated { AppDelegate() }
    let app = NSApplication.shared
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    MainActor.assumeIsolated {
        Log.openFile()
        delegate.coordinator.simulatedName = name
        delegate.coordinator.start()
        delegate.coordinator.update(UUSignals(overlayVisible: true, controllers: .unrecognized, captureActive: nil), now: Date())
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            delegate.coordinator.simulatedName = nil
            delegate.coordinator.update(UUSignals(overlayVisible: false, controllers: .unrecognized, captureActive: false), now: Date())
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
                Log.flush()
                exit(0)
            }
        }
    }
    app.run()
} else {
    let app = NSApplication.shared
    let delegate = MainActor.assumeIsolated { AppDelegate() }
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
