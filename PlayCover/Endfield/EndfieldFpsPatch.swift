//
//  EndfieldFpsPatch.swift
//  PlayCover
//

import Foundation

/// Endfield 帧率 ×2 补丁 (仅字节写入,幂等):
///   __ForceSetFrameRate 的帧率副本 x20 取自 x0 (入口 +0x18):
///   将 `mov x20, x0` 替换为 `add x20, x0, x0`,
///   官方档位 30/45/60 传入后变为 60/90/120。
///   注意: 入口 +0x14 的 `mov x19, x1` (0xAA0103F3) 是标志位透传 (运行时实测 x1=2),
///   不是帧率,切勿误改。帧率流向 x0 → x20 → 尾部 `mov x1, x20` → setter。
/// 经 EndfieldPatchManager.apply 调用时,二进制已被 .bak 恢复为原版,
/// 只存在单向写入;enable 门控在 Manager — 关闭时 Manager 不调用本方法,
/// 撤销由 .bak 恢复承担,补丁本身不写回原字节。
/// 游戏更新后偏移漂移时,字节校验失败会明确报错,不会误写。
struct EndfieldFpsPatch {
    /// __ForceSetFrameRate 函数入口 (llvm 反汇编 .bak 原版确认, file offset)
    private static let forceSetFrameRateOffset: UInt64 = 0xcf1766c
    /// 入口 +0x18 (mov x20, x0) 的文件偏移
    private static let patchOffset: UInt64 = forceSetFrameRateOffset + 0x18
    /// 原指令: mov x20, x0 (0xAA0003F4)
    private static let originalBytes = Data([0xf4, 0x03, 0x00, 0xaa])
    /// 新指令: add x20, x0, x0 (0x8B000014) — x20 = 2 × x0
    private static let doubledBytes = Data([0x14, 0x00, 0x00, 0x8b])

    /// 当前二进制是否已应用 ×2 补丁 (nil = 无法判断,可能已随游戏更新漂移)
    static func isEnabled(to appUrl: URL) -> Bool? {
        guard let current = EndfieldPatchManager.readBytes(
            url: EndfieldPatchManager.unityFrameworkURL(to: appUrl),
            offset: patchOffset, count: 4) else {
            return nil
        }
        if current == doubledBytes {
            return true
        } else if current == originalBytes {
            return false
        }
        return nil
    }

    /// 写入 ×2 补丁 (仅字节写入,幂等 — 与 EndfieldResolutionPatch.apply 结构对齐):
    ///   当前为原版 → 写入 doubled;
    ///   已是 doubled → 直接成功,不写盘。
    ///   其他字节 → 失败(可能是游戏版本更新导致偏移漂移)。
    /// 由 EndfieldPatchManager.apply 调用:调用前已 .bak 恢复为原版;
    /// enable 门控在 Manager,关闭时不调用本方法 (恢复即撤销)。
    /// - Parameter appUrl: app bundle 的根 URL
    /// - Returns: 成功或失败原因
    @discardableResult
    static func apply(to appUrl: URL) -> Result<String, Error> {
        let unityFramework = EndfieldPatchManager.unityFrameworkURL(to: appUrl)

        guard let current = EndfieldPatchManager.readBytes(url: unityFramework,
                                                           offset: patchOffset, count: 4) else {
            return .failure(NSError(domain: "EndfieldFpsPatch", code: 1,
                                   userInfo: [NSLocalizedDescriptionKey: "Failed to read binary at patch offset"]))
        }
        if current == doubledBytes {
            return .success("FPS x2: ON")
        }
        guard current == originalBytes else {
            return .failure(NSError(domain: "EndfieldFpsPatch", code: 2,
                                   userInfo: [NSLocalizedDescriptionKey:
                                       "Unexpected bytes at patch offset, game version may have changed"]))
        }

        guard Macho.patch(url: unityFramework, offset: patchOffset, data: doubledBytes) else {
            return .failure(NSError(domain: "EndfieldFpsPatch", code: 3,
                                   userInfo: [NSLocalizedDescriptionKey: "Write failed (offset out of range?)"]))
        }

        return .success("FPS x2: ON")
    }
}
