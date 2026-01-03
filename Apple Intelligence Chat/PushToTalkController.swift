//
//  PushToTalkController.swift
//  Apple Intelligence Chat
//
//  Created by Mahadik, Amit on 1/2/26.
//


import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class PushToTalkController: PushToTalkManaging {
    @Published private(set) var state: PushToTalkState = .idle
    @Published private(set) var partialTranscript: String = ""

    private let audioSession = AudioSessionManager()
    private let speech = SpeechRecognizer()

    private var finalTranscript: String = ""

    init() {
        speech.onPartial = { [weak self] text in
            Task { @MainActor in self?.partialTranscript = text }
        }
        speech.onFinal = { [weak self] text in
            Task { @MainActor in
                self?.finalTranscript = text
                self?.state = .ready
            }
        }
        speech.onError = { [weak self] err in
            Task { @MainActor in
                self?.state = .error(err.localizedDescription)
            }
        }
    }

    func requestPermissions() async throws {
        state = .requestingPermissions

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            state = .error("Microphone permission denied.")
            return
        }

        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            state = .error("Speech recognition permission denied.")
            return
        }

        state = .ready
    }

    func startRecording() throws {
        guard state == .ready || state == .idle else { return }

        partialTranscript = ""
        finalTranscript = ""
        state = .recording

        try audioSession.configureForPTT()
        try speech.start()
    }

    func stopRecording() -> String {
        guard state == .recording else { return "" }
        state = .processing

        speech.stop()
        audioSession.deactivate()

        // Return whatever we have; onFinal will usually set state back to .ready.
        let text = (partialTranscript.isEmpty ? finalTranscript : partialTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        partialTranscript = ""
        finalTranscript = ""
        return text
    }

    func cancel() {
        speech.cancel()
        audioSession.deactivate()
        partialTranscript = ""
        finalTranscript = ""
        state = .ready
    }
}
