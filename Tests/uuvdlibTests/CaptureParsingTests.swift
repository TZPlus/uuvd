// 控制端表格文字识别 + 推流日志解析
import Foundation
@testable import uuvdlib

func testControllerTable() {
    checkEqual("认出控制行", ControllerTable(rows: [["iPad Pro", "远程控制", "连接时长 00:10"]]).names, ["iPad Pro"])
    check("忽略协助行", ControllerTable(rows: [["某某", "远程协助"]]).names.isEmpty)
    check("空表", ControllerTable(rows: []).names.isEmpty)
    check("时长不是名字", ControllerTable(rows: [["连接时长 00:10", "远程控制"]]).names.isEmpty)
    checkEqual("去重保序", ControllerTable(rows: [["B", "远程控制"], ["A", "远程控制"], ["B", "远程控制"]]).names, ["B", "A"])
}

func testCaptureLogParser() {
    let parser = CaptureLogParser()
    func line(_ message: String, timestamp: String = "2026-11-12 19:01:43.417100+0800", pid: Int = 100) -> String {
        """
        {"eventMessage": "\(message)", "timestamp": "\(timestamp)", "processImagePath": "/Applications/UU远程.app/Contents/MacOS/UURemoteServer", "processID": \(pid)}
        """
    }

    checkEqual("displayID", parser.parse(line: line("-[SCDisplay initWithDict:] ... displayID=79"))?.event, .displayDescribed(79))
    checkEqual("开始推流", parser.parse(line: line("-[SCStream startCaptureWithCompletionHandler:]"))?.event, .captureStarted)
    checkEqual("停止推流", parser.parse(line: line("-[SCStream stopCaptureWithCompletionHandler:]:"))?.event, .captureStopped)
    checkEqual("frameStatus 停止", parser.parse(line: line("Stopping stream due to stream frameStatus"))?.event, .captureStopped)

    let ended = parser.parse(line: line("VTCompressionSessionInvalidate ... encoded 1200 dropped 0 duration 45231 [ms]"))
    checkEqual("编码结束带摘要", ended?.event, .encoderEnded(encoded: 1200, dropped: 0, durationMs: 45231))
    checkEqual("试探会话", parser.parse(line: line("VTCompressionSessionInvalidate"))?.event, .encoderProbeEnded)

    let foreign = """
    {"eventMessage": "-[SCStream startCaptureWithCompletionHandler:]", "timestamp": "2026-11-12 19:01:43.417100+0800", "processImagePath": "/usr/bin/foo", "processID": 1}
    """
    check("忽略其他进程", parser.parse(line: foreign) == nil)
    check("忽略垃圾行", parser.parse(line: "not json") == nil)
    check("忽略空 JSON", parser.parse(line: "{}") == nil)
}

func testCaptureSessionState() {
    func rec(_ event: CaptureLogEvent, _ offset: TimeInterval, pid: pid_t = 100) -> CaptureLogRecord {
        CaptureLogRecord(date: t0.addingTimeInterval(offset), event: event, processID: pid)
    }

    // 开始→停止，3 秒宽限
    do {
        var s = CaptureSessionState()
        s.apply(rec(.displayDescribed(79), 0))
        s.apply(rec(.captureStarted, 1))
        check("推流中", s.isActive(at: t0.addingTimeInterval(2)))
        checkEqual("画面屏 79", s.streamingDisplay(at: t0.addingTimeInterval(2)), 79)

        s.apply(rec(.captureStopped, 3))
        check("宽限内仍活跃", s.isActive(at: t0.addingTimeInterval(4)))
        check("宽限过后停止", !s.isActive(at: t0.addingTimeInterval(7)))
        check("停止后无画面屏", s.streamingDisplay(at: t0.addingTimeInterval(7)) == nil)
    }

    // 推流中途换编码会话不算停
    do {
        var s = CaptureSessionState()
        s.apply(rec(.displayDescribed(1), 0))
        s.apply(rec(.captureStarted, 1))
        s.apply(rec(.encoderEnded(encoded: 10, dropped: 0, durationMs: 100), 10))
        s.apply(rec(.encoderCreated, 10.01))
        check("换编码会话不停", s.isActive(at: t0.addingTimeInterval(20)))
    }

    // 紧跟的常驻第二路不盖掉画面屏
    do {
        var s = CaptureSessionState()
        s.apply(rec(.displayDescribed(79), 0))
        s.apply(rec(.captureStarted, 1))
        s.apply(rec(.displayDescribed(1), 1.05))
        s.apply(rec(.captureStarted, 1.06))
        checkEqual("画面屏仍是 79", s.streamingDisplay(at: t0.addingTimeInterval(2)), 79)
    }

    // 回看只认当前 server 进程的记录
    do {
        let history = [
            rec(.captureStarted, -100, pid: 99),  // 旧进程的开始，没有停止
            rec(.captureStarted, -50, pid: 100),
        ]
        check("当前进程的推流认出来了", CaptureSessionState.resumed(history: history, live: [], server: 100).isActive(at: t0))
        check("无 server 时不回放", !CaptureSessionState.resumed(history: history, live: [], server: nil).isActive(at: t0))
    }
}
