// 连接判定：在场只认正面证据，断开需连续缺席 + 过静默期
@testable import uuvdlib

func testConnectionTracker() {
    // 任一路正面证据立即连入，重复信号不再发事件
    do {
        var s = ConnectionTracker()
        check("缺席无事件", s.update(signals(), now: t0) == nil)
        checkEqual("覆盖窗口立即连入", s.update(signals(overlay: true), now: t0.addingTimeInterval(1)), .connected(controller: nil))
        check("重复信号无新事件", s.update(signals(overlay: true), now: t0.addingTimeInterval(2)) == nil)
    }

    // 连入时带上控制端名字
    do {
        var s = ConnectionTracker()
        checkEqual("连入带名字", s.update(signals(names: ["iPad Pro"]), now: t0), .connected(controller: "iPad Pro"))
        checkEqual("controller 属性", s.controller, "iPad Pro")
    }

    // 没认出控制端不算换人，名字变了才算
    do {
        var s = ConnectionTracker()
        _ = s.update(signals(names: ["A"]), now: t0)
        check("认不出保留原名", s.update(signals(overlay: true), now: t0.addingTimeInterval(1)) == nil)
        checkEqual("换人才报变化", s.update(signals(names: ["B"]), now: t0.addingTimeInterval(2)), .controllerChanged("B"))
    }

    // 断开要同时满足防抖与静默期
    do {
        var s = ConnectionTracker()
        _ = s.update(signals(overlay: true), now: t0)
        s.noteSelfInducedChange(at: t0)
        check("debounce 内不断开", s.update(signals(), now: t0.addingTimeInterval(1)) == nil)
        check("静默期内不断开", s.update(signals(), now: t0.addingTimeInterval(2)) == nil)
        checkEqual("都过了才断开", s.update(signals(), now: t0.addingTimeInterval(6)), .disconnected)
    }

    // 缺席期间信号回来则不断开：缺席未过防抖就回来，重新计时
    do {
        var s = ConnectionTracker()
        _ = s.update(signals(overlay: true), now: t0)
        check("缺席 1s 不断开（防抖内）", s.update(signals(), now: t0.addingTimeInterval(1)) == nil)
        check("信号回来", s.update(signals(overlay: true), now: t0.addingTimeInterval(1.5)) == nil)
        check("重新计时：1s 内不断开", s.update(signals(), now: t0.addingTimeInterval(2.5)) == nil)
        checkEqual("累计过防抖才断开", s.update(signals(), now: t0.addingTimeInterval(3.5)), .disconnected)
    }
}
