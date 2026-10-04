//
//  EndfieldView.swift
//  PlayCover
//
//  The dedicated Endfield tab in the app settings. It owns the three Endfield-only tools -
//  the gamepad map-key fix, the render-resolution patch, and the shader-cache reset - and
//  keeps them out of the generic graphics tab.
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

    // MARK: - Resolution patch
    @State var showResolutionPatchAlert = false
    @State var resolutionPatchResult: String?
    @State var fpsX2Enabled = false
    /// Render resolution = window resolution x scaler (the same value the graphics tab shows).
    private var renderWidth: Int {
        Int(Double(settings.settings.windowWidth) * settings.settings.customScaler)
    }
    private var renderHeight: Int {
        Int(Double(settings.settings.windowHeight) * settings.settings.customScaler)
    }

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
                    .font(.callout)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Text("settings.endfield.resolutionPatch")
                    Spacer()
                    Button("settings.button.endfieldApplyPatch") {
                        showResolutionPatchAlert = true
                    }
                }
                Text("settings.endfield.resolutionPatchHint")
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
        .sheet(isPresented: $showResolutionPatchAlert) {
            VStack(alignment: .leading, spacing: 12) {
                Text("alert.endfieldPatch.title")
                    .font(.headline)
                Text(String(format: NSLocalizedString("alert.endfieldPatch.message", comment: ""),
                            renderWidth, renderHeight))
                    .font(.callout)
                    .foregroundColor(.secondary)
                Toggle("settings.toggle.endfieldFpsX2", isOn: $fpsX2Enabled)
                    .onAppear {
                        fpsX2Enabled = EndfieldFpsPatch.isEnabled(to: app.url) ?? false
                    }
                Text("alert.endfieldPatch.fpsX2Hint")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("alert.endfieldPatch.bottomHint")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Spacer()
                    Button("button.Cancel") {
                        showResolutionPatchAlert = false
                    }
                    .keyboardShortcut(.cancelAction)
                    Button("button.OK") {
                        showResolutionPatchAlert = false
                        applyResolutionPatch()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 380)
        }
        .alert("alert.endfieldPatch.result",
               isPresented: Binding(get: { resolutionPatchResult != nil },
                                    set: { if !$0 { resolutionPatchResult = nil } })) {
            Button("button.OK") {}
        } message: {
            Text(resolutionPatchResult ?? "")
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

    // MARK: - Resolution patch

    func applyResolutionPatch() {
        let outcome = EndfieldPatchManager.apply(to: app.url,
                                                 width: renderWidth,
                                                 height: renderHeight,
                                                 enableFpsX2: fpsX2Enabled)
        var messages: [String] = []
        switch outcome.resolution {
        case .success(let res):
            messages.append(res)
        case .failure(let error):
            messages.append(String(format: NSLocalizedString("alert.endfieldPatch.failure", comment: ""),
                                   error.localizedDescription))
        }
        switch outcome.fpsX2 {
        case .success(let res):
            messages.append(res)
        case .failure(let error):
            messages.append(String(format: NSLocalizedString("alert.endfieldPatch.failure", comment: ""),
                                   error.localizedDescription))
        }

        if case .failure(let error) = outcome.signing {
            messages.append(String(format: NSLocalizedString("alert.endfieldPatch.failure", comment: ""),
                                   error.localizedDescription))
        }

        resolutionPatchResult = messages.joined(separator: "\n")
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
