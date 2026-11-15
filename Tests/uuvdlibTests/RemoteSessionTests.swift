// 会话生命周期：重连窗口内算同一会话，窗口过了才结束
@testable import uuvdlib

func testRemoteSession() {
    // 完整生命周期：began → interrupted → resumed → interrupted → ended
    // （防抖 1.5s：缺席 1s 无事件，缺席累计 2s 判 interrupted）
    var s = RemoteSession()
    checkEqual("began 带名字", s.update(signals(names: ["iPad"]), now: t0), [.began(controller: "iPad")])
    check("inEpisode", s.inEpisode)

    checkEqual("缺席 1s 无事件", s.update(signals(), now: t0.addingTimeInterval(1)), [])
    checkEqual("缺席 2s interrupted", s.update(signals(), now: t0.addingTimeInterval(2)), [.interrupted])
    check("重连窗口内仍 inEpisode", s.inEpisode)

    checkEqual("窗口内重连 resumed", s.update(signals(names: ["iPad"]), now: t0.addingTimeInterval(5)), [.resumed(controller: "iPad")])

    checkEqual("再缺席 1s", s.update(signals(), now: t0.addingTimeInterval(6)), [])
    checkEqual("再 interrupted", s.update(signals(), now: t0.addingTimeInterval(7)), [.interrupted])
    checkEqual("超 15s 窗口 ended", s.update(signals(), now: t0.addingTimeInterval(7 + 16)), [.ended])
    check("结束后不在会话", !s.inEpisode)

    // 重连窗口内仍记着控制端名字
    var s2 = RemoteSession()
    _ = s2.update(signals(names: ["iPad"]), now: t0)
    _ = s2.update(signals(), now: t0.addingTimeInterval(1))
    _ = s2.update(signals(), now: t0.addingTimeInterval(2))
    check("断开时 controller 清空", s2.controller == nil)
    checkEqual("episodeController 保留", s2.episodeController, "iPad")
}
