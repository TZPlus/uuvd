// 显示诊断工具（移植自 UUyc-companion 的 vdprobe，MIT）
// 用法：uuvdprobe --list                       列出当前显示器（只读）
//      uuvdprobe --touch                      执行一次空配置事务，检查 WindowServer 是否响应
//      uuvdprobe <像素宽> <像素高> [停留秒数]   建一块临时虚拟屏、停留、释放，验证建/删链路
import CGVirtualDisplayBridge
import CoreGraphics
import Foundation

let args = CommandLine.arguments

func onlineDisplays() -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    CGGetOnlineDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetOnlineDisplayList(count, &ids, &count)
    return Array(ids.prefix(Int(count)))
}

func describe(_ id: CGDirectDisplayID) -> String {
    let b = CGDisplayBounds(id)
    let mode = CGDisplayCopyDisplayMode(id)
    let px = mode.map { "\($0.pixelWidth)x\($0.pixelHeight)px" } ?? "?"
    let pt = mode.map { "\($0.width)x\($0.height)pt" } ?? "?"
    let vendor = CGDisplayVendorNumber(id)
    let main = CGDisplayIsMain(id) != 0 ? " [主屏]" : ""
    let ours = vendor == 0x5555 ? " [uuvd 身份]" : ""
    return "  #\(id) vendor=0x\(String(vendor, radix: 16)) 原点(\(Int(b.origin.x)),\(Int(b.origin.y))) \(pt) \(px)\(main)\(ours)"
}

func dump(_ title: String) {
    print("== \(title)")
    onlineDisplays().forEach { print(describe($0)) }
}

if args.contains("--list") { dump("当前显示器"); exit(0) }

if args.contains("--touch") {
    var cfg: CGDisplayConfigRef?
    let begin = CGBeginDisplayConfiguration(&cfg)
    guard begin == .success else { print("❌ CGBeginDisplayConfiguration 失败 CGError=\(begin.rawValue)"); exit(1) }
    let err = CGCompleteDisplayConfiguration(cfg, .forSession)
    print(err == .success ? "✅ WindowServer 配置事务正常" : "❌ WindowServer 无响应 CGError=\(err.rawValue)")
    exit(err == .success ? 0 : 1)
}

let pixelW = args.count > 1 ? Int(args[1]) ?? 2360 : 2360
let pixelH = args.count > 2 ? Int(args[2]) ?? 1640 : 1640
let hold = args.count > 3 ? Double(args[3]) ?? 8 : 8
let setMain = args.contains("--main")

let desc = CGVirtualDisplayDescriptor()
desc.name = "uuvd Probe"
desc.maxPixelsWide = UInt32(pixelW)
desc.maxPixelsHigh = UInt32(pixelH)
desc.sizeInMillimeters = CGSize(width: Double(pixelW) / 220 * 25.4, height: Double(pixelH) / 220 * 25.4)
desc.vendorID = 0x5555
desc.productID = 0x0001
desc.serialNum = 0x0001

var vd: CGVirtualDisplay? = autoreleasepool { CGVirtualDisplay(descriptor: desc) }
if vd == nil {
    print("❌ CGVirtualDisplay(descriptor:) 返回 nil —— 私有 API 不可用或同序列号残留")
    exit(1)
}
print("✅ 虚拟屏对象已创建，displayID=\(vd!.displayID)")

let settings = CGVirtualDisplaySettings()
settings.hiDPI = true
settings.modes = [CGVirtualDisplayMode(width: UInt(pixelW / 2), height: UInt(pixelH / 2), refreshRate: 60) as Any]
guard autoreleasepool(invoking: { vd!.apply(settings) }) else {
    print("❌ applySettings 失败")
    exit(2)
}
print("✅ applySettings 成功")

RunLoop.main.run(until: Date().addingTimeInterval(2))
dump("创建后")
let originalMain = CGMainDisplayID()
let savedOrigins = onlineDisplays().filter { $0 != vd!.displayID }.map { ($0, CGDisplayBounds($0).origin) }

if setMain {
    // 把 target 移到 (0,0) 成为主屏，其余显示器整体平移保持相对布局
    let t = CGDisplayBounds(vd!.displayID).origin
    var cfg: CGDisplayConfigRef?
    CGBeginDisplayConfiguration(&cfg)
    for id in onlineDisplays() {
        let o = CGDisplayBounds(id).origin
        CGConfigureDisplayOrigin(cfg, id, Int32(o.x - t.x), Int32(o.y - t.y))
    }
    let err = CGCompleteDisplayConfiguration(cfg, .forSession)
    print(err == .success ? "✅ 已设为主屏" : "❌ 设主屏失败 CGError=\(err.rawValue)")
    RunLoop.main.run(until: Date().addingTimeInterval(1.5))
    dump("设为主屏后")
}

print("…停留 \(Int(hold)) 秒")
RunLoop.main.run(until: Date().addingTimeInterval(hold))

if setMain {
    var cfg: CGDisplayConfigRef?
    CGBeginDisplayConfiguration(&cfg)
    for (id, o) in savedOrigins { CGConfigureDisplayOrigin(cfg, id, Int32(o.x), Int32(o.y)) }
    let err = CGCompleteDisplayConfiguration(cfg, .forSession)
    print(err == .success ? "✅ 已还原原布局" : "⚠️ 还原布局 CGError=\(err.rawValue)")
}

let vid = vd!.displayID
autoreleasepool { vd = nil }  // 释放对象即移除虚拟屏
for _ in 0..<20 where onlineDisplays().contains(vid) {
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
}
dump("释放后")
print(!onlineDisplays().contains(vid) ? "✅ 虚拟屏已消失" : "❌ 虚拟屏残留（WindowServer 卡住，注销或重启后清除）")
print(CGMainDisplayID() == originalMain ? "✅ 主屏已恢复" : "⚠️ 主屏未恢复为 #\(originalMain)")
