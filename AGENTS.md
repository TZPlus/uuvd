# AGENTS.md — uuvd

## 是什么
UU远程 Mac 被控端的最小虚拟屏工具：识别控制端设备 → 按其分辨率建 HiDPI 虚拟屏 → 断开自动还原。基于 UUyc-companion v1.1.3（MIT）精简，吸收其未合并修复 PR #10/#12/#14/#19 与 Snug 的实测教训。

## 目录约定
- `Sources/uuvdlib/` — 纯逻辑 + 系统层库（Session 状态机、感知、显示拓扑），不许依赖 AppKit UI（Sensing 里的进程/窗口观测除外）
- `Sources/uuvd/` — 可执行入口：AppDelegate、菜单栏、快捷键、命令行参数
- `Tests/uuvdlibTests/` — XCTest，只测纯逻辑（状态机、解析、配置）
- `docs/requirements/` — 需求文档（dev-flow 流程产物）
- `vendor/`（工作区级） — 参考仓库，只读，改动必须回本项目的要手动同步

## 工程纪律
- 注释用中文，写"为什么"；commit 中文
- 上游来源的代码改动保留原注释，新增坑记录追加在对应文件头部
- 虚拟屏/物理屏相关代码改动前必读 `Sources/uuvdlib/DisplayManager.swift` 和 `PhysicalDisplays.swift` 头部的坑清单（WindowServer 脆弱性）
- 验证：`swift build` + `swift test`；真机验证需 iPad + UU远程
- 不引入第三方依赖（CGVirtualDisplayBridge 除外，源自 FreeDisplay MIT，已内置）

## 明确不做的
- 不做手机竖屏/窗口管理/手势翻译（Snug 的方向）
- 不做看门狗 LaunchAgent（v0.1；物理屏恢复靠快捷键 + 重启兜底）
- 不做设置窗口 UI（配置文件 `~/Library/Application Support/uuvd/config.json` 手编）
- 自动更新、签名公证：无
