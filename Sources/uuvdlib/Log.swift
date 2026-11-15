// 日志：os.Logger（subsystem local.tz.uuvd）+ 文件镜像（~/Library/Logs/uuvd.log）
import Foundation
import os

public enum LogLevel: String, Sendable {
    case debug, info, warn, error
}

public enum Log {
    public static let subsystem = "local.tz.uuvd"

    private static let logger = Logger(subsystem: subsystem, category: "uuvd")
    private static let state = Locked<FileHandle?>(nil)
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    /// 打开日志文件（调用方决定时机；反复调用幂等）
    public static func openFile() {
        state.withLock { handle in
            guard handle == nil else { return }
            let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Logs/uuvd.log")
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile()
                handle = h
            } else if FileManager.default.createFile(atPath: url.path, contents: nil),
                      let h = try? FileHandle(forWritingTo: url) {
                handle = h
            }
        }
    }

    public static func debug(_ message: String) { emit(.debug, message) }
    public static func info(_ message: String) { emit(.info, message) }
    public static func warn(_ message: String) { emit(.warn, message) }
    public static func error(_ message: String) { emit(.error, message) }

    public static func flush() {
        state.withLock { try? $0?.synchronize() }
    }

    private static func emit(_ level: LogLevel, _ message: String) {
        switch level {
        case .debug: logger.debug("\(message, privacy: .public)")
        case .info: logger.info("\(message, privacy: .public)")
        case .warn: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
        let line = "[\(formatter.string(from: Date()))] [\(level.rawValue)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        state.withLock { $0?.write(data) }
    }
}
