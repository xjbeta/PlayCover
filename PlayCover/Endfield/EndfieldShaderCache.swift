//
//  EndfieldShaderCache.swift
//  PlayCover
//

import Foundation

/// Endfield 着色器缓存清理:
///   游戏自带的「编译着色器缓存」预热流程只看一个 PlayerPrefs 键 `hg_warm_up_once`,
///   其值为游戏版本号 (如 "1.5.3"),语义是"该版本已预热过一次"。
///   macOS 系统更新会作废 Metal 驱动级着色缓存,但游戏版本号不变,
///   游戏因此误判"已预热"而跳过预热,只能在游玩过程中零散重编译,表现为异常卡顿。
///   删除该键后,游戏下次启动会重新执行预热 (出现「编译着色器缓存」进度条)。
///
/// 两点约束:
///   1. 必须在游戏完全退出后执行 —— PlayerPrefs 会在游戏退出时把内存中的旧值写回。
///   2. 只删这一个标记,不碰已编译好的驱动级缓存 (com.apple.metal):
///      那是预热跑出来的成果,删掉等于前功尽弃。
///
/// 读写一律经 `/usr/bin/defaults` 走 cfprefsd,直接改 plist 文件可能被其缓存覆盖。
enum EndfieldShaderCache {
    /// 预热门:值为游戏版本号,删除后游戏判定需要重新预热
    static let gateKey = "hg_warm_up_once"

    /// 游戏 PlayerPrefs 文件路径
    static func prefsURL(for app: PlayApp) -> URL {
        app.container.userPrefsUrl
    }

    /// 读取预热门当前值;nil 表示键不存在 (defaults read 对不存在的键返回非 0)
    static func value(in app: PlayApp) -> String? {
        let url = prefsURL(for: app)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let output = try? Shell.run(print: false, "/usr/bin/defaults", "read", url.path, gateKey) else {
            return nil
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 游戏是否仍在运行。
    /// 运行中清理无意义 (游戏退出时会把旧值写回),因此调用方应先拦下。
    static func isGameRunning(_ app: PlayApp) -> Bool {
        guard let output = try? Shell.run(print: false, "/usr/bin/pgrep", "-f", app.executable.path) else {
            return false
        }
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 删除预热门标记。
    /// - Returns: 成功时 true 表示确实删掉了标记,false 表示本来就不存在 (无需清理)
    @discardableResult
    static func clear(in app: PlayApp) -> Result<Bool, Error> {
        let url = prefsURL(for: app)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(NSError(domain: "EndfieldShaderCache", code: 1,
                                   userInfo: [NSLocalizedDescriptionKey: "Preferences not found"]))
        }
        guard !isGameRunning(app) else {
            return .failure(NSError(domain: "EndfieldShaderCache", code: 2,
                                   userInfo: [NSLocalizedDescriptionKey: "Game is running"]))
        }

        let existed = value(in: app) != nil
        guard existed else { return .success(false) }

        // defaults delete 对不存在的键返回非 0,故不按退出码判成败,以"删完读不到"为准。
        _ = try? Shell.run(print: false, "/usr/bin/defaults", "delete", url.path, gateKey)
        guard value(in: app) == nil else {
            return .failure(NSError(domain: "EndfieldShaderCache", code: 3,
                                   userInfo: [NSLocalizedDescriptionKey: "Failed to remove \(gateKey)"]))
        }
        return .success(true)
    }
}
