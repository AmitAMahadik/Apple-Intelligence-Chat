//
//  PushToTalkManaging.swift
//  Apple Intelligence Chat
//
//  Created by Mahadik, Amit on 1/2/26.
//


//
//  PushToTalkManaging.swift
//  Apple Intelligence Chat
//

import Foundation

@MainActor
protocol PushToTalkManaging: ObservableObject {
    var state: PushToTalkState { get }
    var partialTranscript: String { get }

    func requestPermissions() async throws
    func startRecording() throws
    func stopRecording() -> String     // returns best-effort transcript
    func cancel()
}

enum PushToTalkState: Equatable {
    case idle
    case requestingPermissions
    case ready
    case recording
    case processing
    case error(String)
}