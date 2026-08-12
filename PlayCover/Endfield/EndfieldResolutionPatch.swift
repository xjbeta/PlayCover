//
//  EndfieldResolutionPatch.swift
//  PlayCover
//

import Foundation

/// Endfield 渲染分辨率 + FSR3 锁定:
///   1. GetRenderResolution 中的 csel → movz,强制渲染分辨率
///   2. SetResolutionAndQuality 中的 str → str wzr,强制 FSR3 quality=0 (Native)
/// 只负责字节写入;.bak 恢复与签名由 EndfieldPatchManager 统一负责。
struct EndfieldResolutionPatch {
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

    /// 写入补丁 (仅字节写入;.bak 恢复与签名由 EndfieldPatchManager 负责)。
    /// 使用已知偏移直接定位写入,避免读取整个 300M 文件。
    /// - Parameters:
    ///   - appUrl: app bundle 的根 URL
    ///   - width: 渲染宽度 (1-65535)
    ///   - height: 渲染高度 (1-65535)
    /// - Returns: 成功或失败原因
    @discardableResult
    static func apply(to appUrl: URL, width: Int, height: Int) -> Result<String, Error> {
        let unityFramework = EndfieldPatchManager.unityFrameworkURL(to: appUrl)

        guard Macho.patch(url: unityFramework, offset: patch1Offset,
                          data: movz(reg: 9, imm16: width)),
              Macho.patch(url: unityFramework, offset: patch2Offset,
                          data: movz(reg: 8, imm16: height)),
              Macho.patch(url: unityFramework, offset: fsr3StrOffset,
                          data: strWzr) else {
            return .failure(NSError(domain: "EndfieldResolutionPatch", code: 1,
                                   userInfo: [NSLocalizedDescriptionKey: "Write failed (offset out of range?)"]))
        }

        return .success("\(width)x\(height)")
    }
}
