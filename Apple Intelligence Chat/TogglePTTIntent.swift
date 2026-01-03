//
//  TogglePTTIntent.swift
//  Apple Intelligence Chat
//
//  Created by Mahadik, Amit on 1/3/26.
//


import AppIntents

struct TogglePTTIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Push to Talk"
    static let description =
        LocalizedStringResource("Start or stop voice input in Apple Intelligence Chat.")

    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .togglePTTRequested,
            object: nil
        )
        return .result()
    }
}