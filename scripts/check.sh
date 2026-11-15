#!/bin/zsh
# 验证：构建 + 运行单测小程序（本机 CLT 无 XCTest、swift-testing 宏插件损坏，见 Package.swift 注释）
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
swift run -c debug uuvdtests
echo "✅ check 通过"
