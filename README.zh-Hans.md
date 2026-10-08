<p align="center">
  <a href="README.md">English</a> · <b>简体中文</b>
</p>

<div align="center">
  <img src="images/endfield-logo.png" alt="Logo" width="80" height="80">

  <h3 align="center">PlayCover · 终末地定制版</h3>

  <p align="center">
    基于 <a href="https://github.com/viatearz/PlayCover">viatearz/PlayCover</a> 的 fork，为《明日方舟：终末地》添加额外 patch
    <br />
    <br />
    <a href="https://github.com/xjbeta/PlayCover/actions/workflows/unsigned_release.yml">下载构建 (GitHub Actions)</a>
    ·
    <a href="https://playcover.github.io/PlayBook">上游文档</a>
    ·
    <a href="https://playcover.io/">官网</a>
  </p>
</div>

> [!WARNING]
> 本 fork 的功能都会修改游戏，可能被反作弊检测到，**存在封号风险，请自行承担**。

---

## 这是什么

本仓库是 **[viatearz/PlayCover](https://github.com/viatearz/PlayCover) 的 fork**。

- `viatearz/PlayCover` 本身是 [PlayCover](https://github.com/PlayCover/PlayCover) 的修改版（实验性 bugfix / 功能）；
- 本 fork 在其基础上，**针对《明日方舟：终末地》额外添加了一组 patch 与修复**（见下方「终末地专属功能」）。

> 除终末地相关改动外，其余功能与行为均来自上述上游。本构建为**实验性**版本，可能不稳定；
> 若只需通用功能，建议优先使用官方或 viatearz 的版本。

## 终末地专属功能

游戏设置页新增了一个 **「终末地」Tab**，包含以下开关。所有开关**只对终末地生效**
（按 bundle id `com.hypergryph.endfield` / `com.gryphline.endfield.ios` 门禁），对其他 App 无影响。

| 功能 | 说明 |
|---|---|
| **分辨率修复** | 不再锁死游戏默认的 1080p，改为跟随图像设置中的「分辨率」与「分辨率缩放」 |
| **帧率档位翻倍** | 30/45/60 → 60/90/120，并解开引擎内部帧率上限 |
| **恢复手柄震动** | 修复手柄完全不震 / 普攻不震，并适配多马达手柄（左右握把 + 左右扳机分级输出） |
| **音量增强** | 绕过游戏内 100% 音量上限（在 Wwise 输出后加增益），100–150%，100% 为关闭 |
| **着色器缓存清理** | 删除预热标记，让游戏下次启动重新执行「编译着色器缓存」。macOS 更新后出现异常卡顿时使用 |

### 需要键鼠插件的修复

以下两项依赖第三方插件 **`libUnityDesktopMode`**，未安装插件时开关会被禁用。
从 [Bilibili 视频](https://www.bilibili.com/video/BV14xHz65Eiv) 下载后，在 PlayCover 里安装：
右键 App → **设置 → 杂项 → 自定义插件 → 添加…**，选择 `.dylib` 并确认「仍要添加」。
PlayCover 会把它拷进 App 的 `Frameworks/UserPlugins/`。

| 功能 | 说明 |
|---|---|
| **手柄地图键修复** | 修复安装插件后手柄按键异常的问题 |
| **鼠标视角倍率** | 修复键鼠模式下鼠标转动视角过慢的问题（额外倍率滑条 0–3，1.0 为校正值） |

> **键鼠模式切换**由插件自身负责，本仓库不维护该插件，仅依赖它的存在。

## 如何使用

1. 从 [GitHub Actions](https://github.com/xjbeta/PlayCover/actions/workflows/unsigned_release.yml)
   手动触发 `Build unsigned release`，下载产物 `PlayCover_custom_<run>.dmg`。
2. 安装 App。
3. 去除隔离属性：
   ```bash
   xattr -dr com.apple.quarantine /Applications/PlayCover.app
   ```

### 从官方版本迁移

如果你之前用官方（或其它）构建安装过某个 App，建议：

1. 右键 App 图标 → `设置` → 点击底部 `重置设置`，恢复推荐配置；
2. 重新安装该 App，因为部分 tweak 只在安装时应用。

## 从源码构建

本 fork 依赖 [xjbeta/PlayTools](https://github.com/xjbeta/PlayTools) 的 `dev` 分支（终末地模块所在）。
`Cartfile` 已指向该仓库：

```
github "xjbeta/PlayTools" "dev"
```

构建步骤与上游一致（Carthage + Xcode）。注意 PlayCover 的构建阶段会**重跑 carthage**，
因此 `Cartfile` 指向谁就编谁。

## 许可证

本项目以 **GPLv3** 许可证分发，详见 `LICENSE`。

## 致谢

- [PlayCover](https://github.com/PlayCover/PlayCover) —— 原项目，感谢 @iVoider；
- [viatearz/PlayCover](https://github.com/viatearz/PlayCover) —— 本 fork 的直接上游；
- `libUnityDesktopMode` 插件作者 —— 键鼠模式切换的实现方（外部依赖，不由本仓库维护）；
- [DeepSeek](https://www.deepseek.com/) —— 协助完成终末地相关 patch 的开发。

## 使用的开源库

- [inject](https://github.com/paradiseduo/inject)
- [PTFakeTouch](https://github.com/Ret70/PTFakeTouch)
- [DownloadManager](https://github.com/shapedbyiris/download-manager)
- [DataCache](https://github.com/huynguyencong/DataCache)
- [SwiftUI CachedAsyncImage](https://github.com/bullinnyc/CachedAsyncImage)
