//
//  AppShortcuts.swift
//  Apple Intelligence Chat
//
//  Created by Assistant on 1/3/26.
//

import AppIntents

struct AppleIntelligenceAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TogglePTTIntent(),
            phrases: [
                "Toggle Push to Talk in \(.applicationName)",
                "Start voice input in \(.applicationName)",
                "Stop voice input in \(.applicationName)"
            ],
            shortTitle: "Toggle PTT",
            systemImageName: "mic"
        )
    }
}
