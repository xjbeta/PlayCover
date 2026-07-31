//
//  EndfieldPatch.swift
//  PlayCover
//

import Foundation

/// Endfield 渲染分辨率 + FSR3 锁定:
///   1. GetRenderResolution 中的 csel → movz,强制渲染分辨率
///   2. SetResolutionAndQuality 中的 str → str wzr,强制 FSR3 quality=0 (Native)
/// 使用已知偏移直接定位写入,避免读取整个 300M 文件。
struct EndfieldPatch {
    /// GetRenderResolution 函数偏移(由 patch_binary_fixed.py 验证)
    private static let funcOffset: UInt64 = 0xf847b58
    /// csel w9, w9, w10, gt (选择 width) 的偏移
    private static let patch1Offset: UInt64 = funcOffset + 0x14
    /// csel w8, w9, w8, gt (选择 height) 的偏移
    private static let patch2Offset: UInt64 = funcOffset + 0x28

    /// SetResolutionAndQuality 中 str 指令偏移(由 lldb_4k_fsr3_native.py 验证)
    private static let fsr3StrOffset: UInt64 = 0xec9878c

    /// 编码 ARM64 `movz Wd, #imm16` 指令 (小端序 4 字节 Data)
    private static func movz(reg: Int, imm16: Int) -> Data {
        let instr: UInt32 = 0x52800000 | (UInt32(imm16 & 0xFFFF) << 5) | UInt32(reg & 0x1F)
        return withUnsafeBytes(of: instr.littleEndian) { Data($0) }
    }

    /// str wzr, [x8, #0x20] — 强制 FSR3 quality = 0 (Native)
    private static let strWzr: Data = {
        let instr: UInt32 = 0xb900211f
        return withUnsafeBytes(of: instr.littleEndian) { Data($0) }
    }()

    /// 应用 patch。用户手动触发。
    /// 逻辑:
    ///   1. 无 .bak → 当前 binary 当原版,创建 .bak
    ///   2. 有 .bak → 删除当前,从 .bak 恢复原版
    ///   3. patch + 签名
    /// - Parameters:
    ///   - appUrl: app bundle 的根 URL
    ///   - width: 渲染宽度 (1-65535)
    ///   - height: 渲染高度 (1-65535)
    /// - Returns: 成功或失败原因
    @discardableResult
    static func apply(to appUrl: URL, width: Int, height: Int) -> Result<String, Error> {
        let unityFramework = appUrl.appendingPathComponent("Frameworks")
            .appendingPathComponent("UnityFramework.framework")
            .appendingPathComponent("UnityFramework")

        guard FileManager.default.fileExists(atPath: unityFramework.path) else {
            return .failure(NSError(domain: "EndfieldPatch", code: 1,
                                   userInfo: [NSLocalizedDescriptionKey: "UnityFramework not found"]))
        }

        let backupUrl = unityFramework.appendingPathExtension("bak")

        // 1. 无 .bak → 当前 binary 当原版,创建 .bak
        if !FileManager.default.fileExists(atPath: backupUrl.path) {
            do {
                try FileManager.default.copyItem(at: unityFramework, to: backupUrl)
                print("EndfieldPatch: Backup created from current binary")
            } catch {
                return .failure(error)
            }
        }

        // 2. 删除当前(可能已 patch),从 .bak 恢复原版
        try? FileManager.default.removeItem(at: unityFramework)
        do {
            try FileManager.default.copyItem(at: backupUrl, to: unityFramework)
        } catch {
            return .failure(error)
        }

        // 3. 用 offset 重载直接写入(不读取整个文件)
        //    分辨率:movz 替换 csel
        //    FSR3:str wzr 强制 quality=0 (Native)
        guard Macho.patch(url: unityFramework, offset: patch1Offset,
                          data: movz(reg: 9, imm16: width)),
              Macho.patch(url: unityFramework, offset: patch2Offset,
                          data: movz(reg: 8, imm16: height)),
              Macho.patch(url: unityFramework, offset: fsr3StrOffset,
                          data: strWzr) else {
            return .failure(NSError(domain: "EndfieldPatch", code: 2,
                                   userInfo: [NSLocalizedDescriptionKey: "Write failed (offset out of range?)"]))
        }

        do {
            try Shell.signMacho(unityFramework)
            return .success("\(width)x\(height)")
        } catch {
            return .failure(error)
        }
    }
}
