# uuvd

> v0.1.0 · UU远程 Mac 被控端的最小虚拟屏工具

UU远程 Mac 被控端的最小虚拟屏工具：iPad/手机连上时，自动按该设备的分辨率建一块 HiDPI 虚拟屏，远程画面无黑边；断开后自动移除并还原显示器布局。

基于 [UUyc-companion](https://github.com/aoyamashou/UUyc-companion) v1.1.3（MIT，2026-10 停更）精简，吸收其未合并修复 PR 与 [Snug](https://github.com/zephyr4123/snug) 的实测坑记录。与 UU远程、网易无任何关系，非官方工具。

## 构建与安装

```sh
scripts/build-app.sh            # 构建 build/uuvd.app（ad-hoc 签名）
scripts/build-app.sh --install  # 复制到 /Applications 并启动
```

需要 macOS 14+ 与 Xcode 命令行工具。ad-hoc 签名每次构建后需在「系统设置 › 隐私与安全性 › 辅助功能」重新授权（授权用于读取 UU远程 窗口文字以识别控制端设备）。

## 配置

`~/Library/Application Support/uuvd/config.json`（首次运行自动生成模板）：

```json
{
  "devices": [
    { "name": "iPad Pro", "width": 2388, "height": 1668, "hiDPI": true }
  ],
  "paused": false,
  "disablePhysical": false
}
```

- `name` 必须与 UU远程「全部设备」里的设备名一致
- `hiDPI` 建议保持 `true`（远程清晰度关键，见下方说明）
- `disablePhysical`: 远程期间关闭 Mac 自己的屏幕（防 Dock/窗口跑丢）；万一屏幕没恢复，按 ⌃⌥⌘9 立即恢复
- `setMain`: 把虚拟屏设为主屏（新窗口/Dock 落到虚拟屏）。默认 `false`——该功能要调整显示器布局，本机实测有触发 WindowServer 卡死的风险，不需要就别开
- 不在列表里的设备连上时不做任何调整

## 用法

装好并授权后常驻菜单栏，无需其他操作。手机/iPad 连上后，在 UU远程 的显示列表里选择「uuvd · 设备名」那块屏。

调试参数：`uuvd --simulate "设备名" [秒数]` 模拟连入/断开；`uuvd --dump-controllers` 打印当前控制端。诊断工具 `uuvdprobe`：`--list` 列显示器、`--touch` 检查 WindowServer 配置事务是否响应。验证命令 `scripts/check.sh`（构建+单测）。

## 为什么默认 HiDPI

HiDPI 与 LoDPI 推流的像素数相同，差别在 macOS 的渲染质量：LoDPI 下文字按 1 倍渲染，在 iPad 的 Retina 屏上要么整体缩小一倍（分辨率不变），要么放大发虚（逻辑分辨率减半）。HiDPI 是远程文字可读的关键，代价仅是 Mac 端 GPU 渲染负载。

## 已知限制

- 依赖 macOS 私有接口（CGVirtualDisplay、CGSConfigureDisplayEnabled），系统大版本升级后可能失效
- 通过 UU远程 窗口文字识别设备，UU远程 改版后可能读不到（读不到时不做调整，交给 UU远程 处理）
- `setMain` / `disablePhysical` 涉及显示器配置事务，在虚拟屏上线前后执行有几率触发 WindowServer 瞬时无响应（CGError 1014）：已做重试与布局无变化跳过，极端情况下会进入保护状态（停止一切显示操作），注销或重启可恢复
- 屏幕拓扑变化频繁时有极低概率触发 WindowServer 显示服务重启（表现为被注销），远程前保存好工作
