//
//  EndfieldView.swift
//  PlayCover
//
//  The dedicated Endfield tab in the app settings. It owns the Endfield-only tools:
//  the three runtime fixes (resolution, fps x2, haptics), the shader-cache reset, and the
//  libUnityDesktopMode-gated fixes (gamepad map key, mouse delta). They are kept out of the
//  generic graphics tab.
//
//  The resolution / fps / haptics switches are plain settings flags: PlayTools reads them at
//  launch and applies the fix in process memory (no on-disk patching, no re-signing).
//

import SwiftUI

// swiftlint:disable:next type_body_length
struct EndfieldView: View {
    @Binding var settings: AppSettings
    var app: PlayApp

    // `AppSettings` is a plain class, so writing `settings.extraSettings.x` through the binding
    // persists but does not invalidate the view. Mirror it locally so the toggle redraws at once.
    @State private var gamepadMapKey = false
    @State private var mouseDeltaScale = 1.0
    @State private var hasPlugin = false

    // MARK: - Runtime fixes
    @State private var resolutionFix = false
    @State private var fpsFix = false
    @State private var hapticsFix = false
    @State private var volumeBoost = 100.0

    // MARK: - Shader cache
    @State var showShaderCacheAlert = false
    @State var shaderCacheStatus: String?
    @State var shaderCacheResult: String?

    /// The plugin-attached fixes only make sense when libUnityDesktopMode is installed.
    static func pluginInstalled(_ app: PlayApp) -> Bool {
        PlayTools.userDylibs(bundleIdentifier: app.info.bundleIdentifier)
            .contains { $0.lastPathComponent == "libUnityDesktopMode.dylib" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("settings.endfield.riskWarning")
                    .font(.body)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Toggle("settings.toggle.endfieldResolutionFix", isOn: $resolutionFix)
                        .onAppear { resolutionFix = settings.extraSettings.endfieldResolutionFix }
                        .onChange(of: resolutionFix) { _ in
                            settings.extraSettings.endfieldResolutionFix = resolutionFix
                        }
                    Spacer()
                }
                Text("settings.endfield.resolutionFixHint")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Toggle("settings.toggle.endfieldFpsFix", isOn: $fpsFix)
                        .onAppear { fpsFix = settings.extraSettings.endfieldFpsFix }
                        .onChange(of: fpsFix) { _ in
                            settings.extraSettings.endfieldFpsFix = fpsFix
                        }
                    Spacer()
                }
                Text("settings.endfield.fpsFixHint")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Toggle("settings.toggle.endfieldHaptics", isOn: $hapticsFix)
                        .onAppear { hapticsFix = settings.extraSettings.endfieldHaptics }
                        .onChange(of: hapticsFix) { _ in
                            settings.extraSettings.endfieldHaptics = hapticsFix
                        }
                    Spacer()
                }
                Text("settings.endfield.hapticsHint")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text(String(format: NSLocalizedString("settings.endfield.volumeBoost", comment: ""),
                                volumeBoost))
                        .help("settings.endfield.volumeBoost.help")
                    Spacer()
                    Slider(value: $volumeBoost, in: 100...150, step: 5, label: { EmptyView() })
                        .frame(width: 200)
                        .onAppear { volumeBoost = settings.extraSettings.endfieldVolumeBoost }
                        .onChange(of: volumeBoost) { _ in
                            settings.extraSettings.endfieldVolumeBoost = volumeBoost
                        }
                }
                Text("settings.endfield.volumeBoostHint")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                HStack {
                    Text("settings.endfield.shaderCache")
                    Spacer()
                    Button("settings.button.endfieldShaderCache") {
                        shaderCacheStatus = EndfieldShaderCache.value(in: app)
                        showShaderCacheAlert = true
                    }
                }
                Text("settings.endfield.shaderCacheHint")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Text("settings.endfield.pluginSection")
                    .bold()

                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.endfield.pluginHint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("settings.endfield.pluginLink",
                         destination: URL(string: "https://www.bilibili.com/video/BV14xHz65Eiv")!)
                        .font(.caption)
                    HStack {
                        Button("settings.endfield.checkPlugin") {
                            // The button is the gate: it unlocks the fixes below and records the
                            // decision, which is what PlayTools reads.
                            hasPlugin = EndfieldView.pluginInstalled(app)
                            settings.extraSettings.endfieldPluginFixes = hasPlugin
                        }
                        if hasPlugin {
                            Text("settings.endfield.pluginFound")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                HStack {
                    Toggle("settings.toggle.endfieldGamepadMapKey", isOn: $gamepadMapKey)
                        .help("settings.toggle.endfieldGamepadMapKey.help")
                        .disabled(!hasPlugin)
                        .onAppear { gamepadMapKey = settings.extraSettings.endfieldGamepadMapKey }
                        .onChange(of: gamepadMapKey) { _ in
                            settings.extraSettings.endfieldGamepadMapKey = gamepadMapKey
                        }
                    Spacer()
                }
                Text("settings.endfield.gamepadMapKeyHint")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text(String(format: NSLocalizedString("settings.endfield.mouseDeltaScale", comment: ""),
                                mouseDeltaScale))
                        .help("settings.endfield.mouseDeltaScale.help")
                    Spacer()
                    Slider(value: $mouseDeltaScale, in: 0...3, step: 0.05, label: { EmptyView() })
                        .frame(width: 200)
                        .onAppear { mouseDeltaScale = settings.extraSettings.endfieldMouseDeltaScale }
                        .onChange(of: mouseDeltaScale) { _ in
                            settings.extraSettings.endfieldMouseDeltaScale = mouseDeltaScale
                        }
                }
                .disabled(!hasPlugin)

                Text("settings.endfield.mouseDeltaScaleHint")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Auto-check once when the settings open; the button re-checks on demand.
            hasPlugin = EndfieldView.pluginInstalled(app)
            settings.extraSettings.endfieldPluginFixes = hasPlugin
        }
        .sheet(isPresented: $showShaderCacheAlert) {
            VStack(alignment: .leading, spacing: 12) {
                Text("alert.endfieldShaderCache.title")
                    .font(.headline)
                Text("alert.endfieldShaderCache.message")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text(String(format: NSLocalizedString("alert.endfieldShaderCache.status", comment: ""),
                            shaderCacheStatus
                                ?? NSLocalizedString("alert.endfieldShaderCache.status.absent", comment: "")))
                    .font(.caption)
                Text("alert.endfieldShaderCache.hint")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Spacer()
                    Button("button.Cancel") {
                        showShaderCacheAlert = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Button("button.Clear") {
                        showShaderCacheAlert = false
                        clearShaderCache()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 380)
        }
        .alert("alert.endfieldShaderCache.result",
               isPresented: Binding(get: { shaderCacheResult != nil },
                                    set: { if !$0 { shaderCacheResult = nil } })) {
            Button("button.OK") {}
        } message: {
            Text(shaderCacheResult ?? "")
        }
    }

    // MARK: - Shader cache

    /// Deletes `hg_warm_up_once` so the game re-runs "Compiling Shader Cache" on next launch.
    func clearShaderCache() {
        if EndfieldShaderCache.isGameRunning(app) {
            shaderCacheResult = NSLocalizedString("alert.endfieldShaderCache.gameRunning", comment: "")
            return
        }
        switch EndfieldShaderCache.clear(in: app) {
        case .success(let removed):
            shaderCacheResult = removed
                ? String(format: NSLocalizedString("alert.endfieldShaderCache.success", comment: ""),
                         EndfieldShaderCache.gateKey)
                : NSLocalizedString("alert.endfieldShaderCache.absent", comment: "")
        case .failure(let error):
            shaderCacheResult = String(
                format: NSLocalizedString("alert.endfieldShaderCache.failure", comment: ""),
                error.localizedDescription)
        }
    }
}
