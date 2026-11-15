// 远程期间禁用物理屏（CGSConfigureDisplayEnabled 私有 API）及其兜底恢复
// 实测（macOS 27，UUyc）：
//   - 禁用不受 .forAppOnly 约束，进程退出后不会自动恢复，必须由别的进程重新启用
//   - 被禁用的屏会从 CGGetOnlineDisplayList 中消失，所以禁用前必须先把 ID 写盘
//   - 物理屏全禁用且虚拟屏也移除时，系统会生成一块 1920×1080 占位屏；按 ID 重新启用即可恢复
// 本文件相对 UUyc v1.1.3 吸收了其未合并 PR #12 + #19：
//   - 恢复时跳过已在线且激活的 ID（看门狗或系统可能已恢复；重复启用事务会失败并卡住启动恢复）
//   - 批量恢复失败时（混有已失效的 Display ID，返回 CGError=1001）逐个恢复并剔除失效 ID，避免整批卡死
// （源自 UUyc-companion，MIT）
import CoreGraphics
import Foundation

/// 同步执行一次显示器配置事务。GUI 进程中不可在主线程调用（会与自身重配置通知死锁）
@discardableResult
func applyDisplayConfig(_ body: (CGDisplayConfigRef?) -> Void) -> CGError {
    var cfg: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&cfg) == .success else { return .failure }
    body(cfg)
    let err = CGCompleteDisplayConfiguration(cfg, .forSession)
    if err != .success { CGCancelDisplayConfiguration(cfg) }
    return err
}

enum PhysicalDisplays {
    private typealias EnableFn = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError
    private static let setEnabled: EnableFn? = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSConfigureDisplayEnabled")
        .map { unsafeBitCast($0, to: EnableFn.self) }

    static var available: Bool { setEnabled != nil }

    /// 已被禁用、待恢复的物理屏记录
    static let markerURL = ConfigStore.dir.appendingPathComponent("disabled-displays.json")

    static var pending: [CGDirectDisplayID]? {
        guard let data = try? Data(contentsOf: markerURL),
              let ids = try? JSONDecoder().decode([CGDirectDisplayID].self, from: data), !ids.isEmpty else { return nil }
        return ids
    }

    /// 先记账再禁用。须在后台队列调用
    static func disable(_ ids: [CGDirectDisplayID]) -> CGError {
        guard let setEnabled, !ids.isEmpty else { return .failure }
        let merged = Array(Set((pending ?? []) + ids))
        guard (try? JSONEncoder().encode(merged).write(to: markerURL, options: .atomic)) != nil else {
            Log.error("❌ 无法写入物理屏记录，放弃禁用")
            return .failure
        }
        return applyDisplayConfig { cfg in ids.forEach { _ = setEnabled(cfg, $0, false) } }
    }

    static func isAlreadyActive(_ id: CGDirectDisplayID) -> Bool {
        // 查询失败/无 WindowServer 连接时返回值可能为 -1，只接受明确的 1
        CGDisplayIsOnline(id) == 1 && CGDisplayIsActive(id) == 1
    }

    /// 按记录重新启用物理屏；成功后删除记录。可在任意进程调用，重复调用无害
    @discardableResult
    static func restore(reason: String,
                        isActive: (CGDirectDisplayID) -> Bool = isAlreadyActive) -> Bool {
        guard let ids = pending else { return true }
        guard let setEnabled else { return false }

        // 看门狗或系统可能已经恢复了屏幕。对已经在线且激活的 ID 再执行
        // 私有启用事务可能失败，不能因此永远卡在启动恢复阶段
        let remaining = ids.filter { !isActive($0) }
        if remaining.isEmpty {
            do { try FileManager.default.removeItem(at: markerURL) }
            catch { Log.warn("⚠️ 无法清理物理屏恢复记录：\(error)"); return false }
            Log.info("✅ 物理屏已处于激活状态，清理残留记录（\(reason)）")
            return true
        }

        let err = applyDisplayConfig { cfg in remaining.forEach { _ = setEnabled(cfg, $0, true) } }
        if err == .success {
            try? FileManager.default.removeItem(at: markerURL)
            Log.info("✅ 已恢复物理屏 \(remaining)（\(reason)）")
            return true
        }

        // 批量恢复失败时（常见于其中混有已断开/重排失效的 Display ID，返回 CGError=1001），
        // 退回逐个恢复，并剔除已失效的 ID，避免整批卡死后续流程
        var restored: [CGDirectDisplayID] = []
        var stale: [CGDirectDisplayID] = []
        var failed: [CGDirectDisplayID] = []
        var lastError = err
        for id in remaining {
            let singleErr = applyDisplayConfig { _ = setEnabled($0, id, true) }
            switch singleErr {
            case .success:
                restored.append(id)
            case .illegalArgument:
                stale.append(id)
            default:
                failed.append(id)
                lastError = singleErr
            }
        }

        if failed.isEmpty {
            try? FileManager.default.removeItem(at: markerURL)
            if !restored.isEmpty && !stale.isEmpty {
                Log.info("✅ 已恢复物理屏 \(restored)，并清理失效 ID \(stale)（\(reason)）")
            } else if !restored.isEmpty {
                Log.info("✅ 已恢复物理屏 \(restored)（\(reason)）")
            } else {
                Log.warn("⚠️ 残留物理屏 ID \(stale) 已失效，已清理记录（\(reason)）")
            }
            return true
        }

        if failed.count != ids.count {
            try? JSONEncoder().encode(failed).write(to: markerURL, options: .atomic)
        }
        Log.warn("⚠️ 恢复物理屏失败 CGError=\(lastError.rawValue)（\(reason)），剩余 \(failed) 稍后重试")
        return false
    }
}
