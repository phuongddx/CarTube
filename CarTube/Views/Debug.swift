//
//  Debug.swift
//  CarTube
//
//  Created by Rory Madden on 6/1/2023.
//

import SwiftUI
import WebKit
import ObjectiveC

struct Debug: View {
    @State private var autoResizeInstalled = false
    @State private var hideScrollBarInstalled = false
    @State private var keyboardAPIAvailable = false
    @State private var idleTimerDisabled = false

    var body: some View {
        Form {
            List {
                Section {
                    Button("Go Back in Browser") {
                        CarPlaySingleton.shared.goBack()
                    }
                    Button("Go Home in Browser") {
                        CarPlaySingleton.shared.goHome()
                    }
                    Button("Toggle CarPlay Keyboard") {
                        CarPlaySingleton.shared.toggleKeyboard()
                    }
                }
                Section(header: Text("Hook Verification"), footer: Text("Live runtime status of every surviving hook at the current iOS floor.")) {
                    Button("Refresh Status") {
                        refreshHookStatus()
                    }
                    hookStatusRow(name: "AutoResize", installed: autoResizeInstalled)
                    hookStatusRow(name: "HideScrollBar", installed: hideScrollBarInstalled)
                    hookStatusRow(name: "Keyboard Private API", installed: keyboardAPIAvailable)
                    hookStatusRow(name: "Idle Timer Disabled", installed: idleTimerDisabled)
                }
                Section(header: Text("Script Re-validation"), footer: Text("Forces the script on and reloads the CarPlay webview in place.")) {
                    Button("Force AdBlocker On") {
                        forceScriptOn(key: "AdBlockerOn", name: "AdBlocker")
                    }
                    Button("Force SponsorBlock On") {
                        forceScriptOn(key: "SponsorBlockOn", name: "SponsorBlock")
                    }
                    Button("Force AgeRestrictBypass On") {
                        forceScriptOn(key: "AgeRestrictBypassOn", name: "AgeRestrictBypass")
                    }
                }
            }
        }
        .navigationBarTitle("Debug", displayMode: .inline)
        .onAppear {
            refreshHookStatus()
        }
    }

    private func hookStatusRow(name: String, installed: Bool) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(installed ? "PASS" : "FAIL")
                .foregroundColor(installed ? .green : .red)
        }
    }

    private func refreshHookStatus() {
        autoResizeInstalled = class_getInstanceMethod(UIWindow.self, NSSelectorFromString("original_setRootViewController:")) != nil
        hideScrollBarInstalled = Debug.checkHideScrollBarInstalled()
        keyboardAPIAvailable = WKWebView.instancesRespond(to: NSSelectorFromString("_simulateTextEntered:"))
        idleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
    }

    // HideScrollBar.m declares only hook_layoutSubviews (no original_ companion), so
    // install detection must compare IMPs instead of probing for an original_ selector.
    private static func checkHideScrollBarInstalled() -> Bool {
        guard let scrollBarClass = NSClassFromString("_UIStaticScrollBar"),
              let superclass = class_getSuperclass(scrollBarClass) else { return false }
        let selector = NSSelectorFromString("layoutSubviews")
        guard let currentIMP = class_getMethodImplementation(scrollBarClass, selector),
              let superclassIMP = class_getMethodImplementation(superclass, selector) else { return false }
        return unsafeBitCast(currentIMP, to: UnsafeRawPointer.self) != unsafeBitCast(superclassIMP, to: UnsafeRawPointer.self)
    }

    private func forceScriptOn(key: String, name: String) {
        UserDefaults.standard.set(true, forKey: key)
        CarPlaySingleton.shared.applyConfiguration()
        UIApplication.shared.alert(title: "Script Forced On", body: "\(name) is now enabled and the CarPlay webview reloaded in place.", window: .main)
    }
}

struct Debug_Previews: PreviewProvider {
    static var previews: some View {
        Debug()
    }
}
