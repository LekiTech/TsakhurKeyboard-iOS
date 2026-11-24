//
//  TsakhurKeyboardApp.swift
//  TsakhurKeyboard
//
//  The containing app: installation instructions and information about
//  the keyboard. The keyboard itself lives in TsakhurKeyboardExtension.
//

import SwiftUI
import GeneralKeyboardBridge

@main
struct TsakhurKeyboardApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active,
                  let bridge = ContributionBridge.productionDirectory(
                      appGroupID: TsakhurIdentity.appGroupID) else { return }
            // Passive by design: batch files exist only if the keyboard's
            // exporter — behind its build flag, user consent, and Full
            // Access — ever wrote any. Today it cannot, so this scans an
            // empty directory and acknowledges nothing.
            _ = ContributionInbox.pickUp(from: bridge)
        }
    }
}
