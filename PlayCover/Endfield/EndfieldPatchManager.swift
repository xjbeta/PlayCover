//
//  EndfieldPatchManager.swift
//  PlayCover
//

import Foundation

/// Endfield 补丁统一管理:负责文件定位/读取/.bak 恢复/签名等共用文件操作,
///   并编排分辨率补丁与 FPS ×2 补丁的联合应用与最终统一签名。
/// 两个补丁只做字节写入,字节级逻辑保留在各自文件 (EndfieldResolutionPatch / EndfieldFpsPatch)。
enum EndfieldPatchManager {
    /// 两个补丁共用的 UnityFramework 二进制路径
    static func unityFrameworkURL(to appUrl: URL) -> URL {
        appUrl.appendingPathComponent("Frameworks")
            .appendingPathComponent("UnityFramework.framework")
            .appendingPathComponent("UnityFramework")
    }

    /// 读取指定偏移处的字节 (file offset)。seek 失败时返回 nil (fail-closed),
    /// 避免静默从错误位置读到字节导致误判。
    static func readBytes(url: URL, offset: UInt64, count: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard (try? handle.seek(toOffset: offset)) != nil else { return nil }
        return try? handle.read(upToCount: count)
    }

    /// .bak 恢复:
    ///   无 .bak → 当前 binary 当原版复制一份 .bak;
    ///   有 .bak → 删除当前,从 .bak 恢复原版。
    /// - Returns: 恢复后的 UnityFramework URL,或失败原因
    static func restoreFromBackup(to appUrl: URL) -> Result<URL, Error> {
        let binary = unityFrameworkURL(to: appUrl)
        guard FileManager.default.fileExists(atPath: binary.path) else {
            return .failure(NSError(domain: "EndfieldPatchManager", code: 1,
                                   userInfo: [NSLocalizedDescriptionKey: "UnityFramework not found"]))
        }

        let backup = binary.appendingPathExtension("bak")
        if !FileManager.default.fileExists(atPath: backup.path) {
            do {
                try FileManager.default.copyItem(at: binary, to: backup)
            } catch {
                return .failure(error)
            }
        }

        try? FileManager.default.removeItem(at: binary)
        do {
            try FileManager.default.copyItem(at: backup, to: binary)
            return .success(binary)
        } catch {
            return .failure(error)
        }
    }

    struct Outcome {
        var resolution: Result<String, Error>
        var fpsX2: Result<String, Error>
        var signing: Result<Void, Error>
    }

    /// 联合操作:先 .bak 恢复原版,再依次执行两个补丁的字节写入,
    /// 最后统一重签名 (无论哪个补丁写入了文件,都能被签名覆盖)。
    /// .bak 恢复同时承担两个补丁的"撤销":每次都是从原版出发重新写入,
    /// FPS ×2 关闭 (enableFpsX2=false) 时不调用 FPS 补丁,直接返回 OFF。
    /// 恢复失败时跳过两个补丁:二进制可能处于缺失/半恢复等未知状态,不应写入。
    @discardableResult
    static func apply(to appUrl: URL, width: Int, height: Int, enableFpsX2: Bool) -> Outcome {
        let resolution: Result<String, Error>
        let fpsX2: Result<String, Error>
        switch restoreFromBackup(to: appUrl) {
        case .success:
            resolution = EndfieldResolutionPatch.apply(to: appUrl, width: width, height: height)
            fpsX2 = enableFpsX2
                ? EndfieldFpsPatch.apply(to: appUrl)
                : .success("FPS x2: OFF")
        case .failure(let error):
            resolution = .failure(error)
            fpsX2 = .failure(error)
        }

        let signing: Result<Void, Error>
        do {
            try Shell.signMacho(unityFrameworkURL(to: appUrl))
            signing = .success(())
        } catch {
            signing = .failure(error)
        }

        return Outcome(resolution: resolution, fpsX2: fpsX2, signing: signing)
    }
}
