//
//  EndfieldResolutionPatch.swift
//  PlayCover
//

import Foundation

/// Endfield 渲染分辨率补丁 (1.5.3):
///   1. GetRenderResolution 中的 csel → movz,强制渲染分辨率 (使 PlayCover UI 设置生效)
///   2. SetOverrideResolution 改为 override = set (游戏设置分辨率):
///      渲染器实际读 override(+0x24/+0x28),而 C# 启动时经 SetOverrideResolution(1920,1080) 写死 1080p,
///      改为读 set 字段再写,override 动态跟随分辨率设置。
/// 1.5.3 不需要 FSR3 补丁 (quality 字段不影响渲染分辨率,经用户实测确认)。
/// 只负责字节写入;.bak 恢复与签名由 EndfieldPatchManager 统一负责。
struct EndfieldResolutionPatch {
    /// GetRenderResolution 函数偏移 (1.5.3 重定位, relocate_new_version.py 验证)
    private static let funcOffset: UInt64 = 0xed81ae4
    /// csel w9, w9, w10, gt (选择 width) 的偏移
    private static let patch1Offset: UInt64 = funcOffset + 0x14
    /// csel w8, w9, w8, gt (选择 height) 的偏移
    private static let patch2Offset: UInt64 = funcOffset + 0x28

    /// SetOverrideResolution 补丁起点 (1.5.3): override = set (游戏设置分辨率)
    /// 利用 override 位于 set 之后 +0x24,用 add 偏移替代重算 adrp,仅需 5 条指令
    private static let overridePatchOffset: UInt64 = 0xe1d15e8
    /// 原指令序列 (20 字节, 0xe1d15e8~0xe1d15fb): 存传入参数到 override
    private static let overrideOriginalBytes = Data([
        0x08, 0xb1, 0x3b, 0x91, // add x8,x8,#0xeec   (x8=&override_w)
        0x13, 0x51, 0x00, 0x29, // stp w19,w20,[x8]   (override=传入参数 1920x1080)
        0x7f, 0x06, 0x00, 0x71, // cmp w19,#0x1
        0xab, 0x02, 0x00, 0x54, // b.lt
        0x9f, 0x06, 0x00, 0x71, // cmp w20,#0x1
    ])
    /// 新指令序列: override = set (动态跟随游戏设置分辨率)
    private static let overridePatchedBytes = Data([
        0x08, 0x21, 0x3b, 0x91, // add x8,x8,#0xec8   (x8=&set_w)
        0x13, 0x51, 0x40, 0x29, // ldp w19,w20,[x8]   (载入 set 分辨率)
        0x08, 0x91, 0x00, 0x91, // add x8,x8,#0x24    (x8=&override_w)
        0x13, 0x51, 0x00, 0x29, // stp w19,w20,[x8]   (override=set)
        0x14, 0x00, 0x00, 0x14, // b 0xe1d1648        (跳到 epilogue)
    ])

    /// 编码 ARM64 `movz Wd, #imm16` 指令 (小端序 4 字节 Data)
    private static func movz(reg: Int, imm16: Int) -> Data {
        let instr: UInt32 = 0x52800000 | (UInt32(imm16 & 0xFFFF) << 5) | UInt32(reg & 0x1F)
        return withUnsafeBytes(of: instr.littleEndian) { Data($0) }
    }

    /// 写入补丁 (仅字节写入;.bak 恢复与签名由 EndfieldPatchManager 负责)。
    /// 使用已知偏移直接定位写入,避免读取整个 300M 文件。
    /// override 补丁带字节校验 (20 字节序列,偏移漂移会明确报错,不误写)。
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
                          data: movz(reg: 8, imm16: height)) else {
            return .failure(NSError(domain: "EndfieldResolutionPatch", code: 1,
                                   userInfo: [NSLocalizedDescriptionKey: "Write failed (offset out of range?)"]))
        }

        guard let current = EndfieldPatchManager.readBytes(url: unityFramework,
                                                           offset: overridePatchOffset,
                                                           count: overridePatchedBytes.count) else {
            return .failure(NSError(domain: "EndfieldResolutionPatch", code: 2,
                                   userInfo: [NSLocalizedDescriptionKey: "Failed to read binary at override offset"]))
        }
        if current != overrideOriginalBytes && current != overridePatchedBytes {
            return .failure(NSError(domain: "EndfieldResolutionPatch", code: 3,
                                   userInfo: [NSLocalizedDescriptionKey:
                                       "Unexpected bytes at override offset, game version may have changed"]))
        }
        guard current != overridePatchedBytes else {
            return .success("\(width)x\(height)")
        }
        guard Macho.patch(url: unityFramework, offset: overridePatchOffset,
                          data: overridePatchedBytes) else {
            return .failure(NSError(domain: "EndfieldResolutionPatch", code: 4,
                                   userInfo: [NSLocalizedDescriptionKey: "Write failed (offset out of range?)"]))
        }

        return .success("\(width)x\(height)")
    }
}
