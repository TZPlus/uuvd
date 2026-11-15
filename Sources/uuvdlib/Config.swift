// 设备配置与持久化（源自 UUyc-companion，MIT，精简：去掉类型分组/导入元数据/预填逻辑）
import Foundation

public struct DeviceConfig: Codable, Identifiable, Hashable {
    public var name: String
    /// 横屏原生像素，由用户自己填写；0 表示还没填
    public var width: Int
    public var height: Int
    public var hiDPI: Bool
    public var id: String { name }

    public init(name: String, width: Int, height: Int, hiDPI: Bool = true) {
        self.name = name
        self.width = width
        self.height = height
        self.hiDPI = hiDPI
    }

    /// 填了合理的分辨率才建虚拟屏
    public var hasSize: Bool { DeviceConfig.validSize.contains(width) && DeviceConfig.validSize.contains(height) }
    public static let validSize = 320...16384

    public var sizeLabel: String { "\(width)×\(height)\(hiDPI ? " 高清" : "")" }
}

public struct AppConfig: Codable {
    public var devices: [DeviceConfig] = []
    public var paused = false
    /// 远程时关闭物理屏（缺省关闭，配置里显式开启）
    public var disablePhysical: Bool?

    public init() {}

    public var shouldDisablePhysical: Bool { disablePhysical ?? false }
}

public final class ConfigStore {
    public static let shared = ConfigStore()

    public static let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("uuvd", isDirectory: true)
    private let url = ConfigStore.dir.appendingPathComponent("config.json")

    public var config: AppConfig {
        didSet { save() }
    }

    public var isConfigured: Bool { config.devices.contains { $0.hasSize } }

    private init() {
        try? FileManager.default.createDirectory(at: ConfigStore.dir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = decoded
        } else {
            config = AppConfig()
            saveTemplate()
        }
    }

    /// 首次运行写一个带注释例子的模板，用户照抄改
    private func saveTemplate() {
        let template = """
        {
          "devices": [
            { "name": "iPad Pro", "width": 2388, "height": 1668, "hiDPI": true }
          ],
          "paused": false,
          "disablePhysical": false
        }
        """
        try? template.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    public func device(named name: String?) -> DeviceConfig? {
        guard let name else { return nil }
        return config.devices.first { $0.name == name }
    }

    private func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(config) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
