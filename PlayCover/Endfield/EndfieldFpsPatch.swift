//
//  EndfieldFpsPatch.swift
//  PlayCover
//

import Foundation

/// Endfield 帧率 ×2 补丁 (仅字节写入,幂等):
///   1.5.3 的 Application::set_targetFrameRate icall 跳板 (0xcec95c0):
///     fps 整数值在 x0 → `mov x19,x0` (0xcec95cc) → 尾部 `mov x0,x19` + `br x1` 调到实现。
///   将 `mov x19,x0` 替换为 `add x19,x0,x0` (0x8B000013), 帧率翻倍。
///   官方档位 30/45/60 传入后变为 60/90/120。
///   ⚠️ 经 LLDB 运行时验证: 翻倍此 icall 的 fps 同时解锁引擎内部限制器与 CADisplayLink,
///      Metal HUD 实际达到 90/120。仅 hook CADisplayLink 无效 (引擎内部另有限制器)。
/// 经 EndfieldPatchManager.apply 调用时,二进制已被 .bak 恢复为原版,
/// 只存在单向写入;enable 门控在 Manager — 关闭时 Manager 不调用本方法,
/// 撤销由 .bak 恢复承担,补丁本身不写回原字节。
/// 游戏更新后偏移漂移时,字节校验失败会明确报错,不会误写。
struct EndfieldFpsPatch {
    /// Application::set_targetFrameRate icall 跳板入口 (1.5.3 重定位, file offset)
    private static let forceSetFrameRateOffset: UInt64 = 0xcec95c0
    /// 入口 +0xc (mov x19, x0) 的偏移 — fps 值装入 x19 的位置
    private static let patchOffset: UInt64 = forceSetFrameRateOffset + 0xc
    /// 原指令: mov x19, x0 (0xAA0003F3)
    private static let originalBytes = Data([0xf3, 0x03, 0x00, 0xaa])
    /// 新指令: add x19, x0, x0 (0x8B000013) — x19 = 2 × x0
    private static let doubledBytes = Data([0x13, 0x00, 0x00, 0x8b])

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
