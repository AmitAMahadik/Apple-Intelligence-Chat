//
//  SpeechRecognizer.swift
//  Apple Intelligence Chat
//
//  Created by Mahadik, Amit on 1/2/26.
//


import Foundation
import Speech
import AVFoundation

final class SpeechRecognizer {
    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    func start() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "SpeechRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"])
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { throw NSError(domain: "SpeechRecognizer", code: 2) }
        request.shouldReportPartialResults = true

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.onPartial?(text)

                if result.isFinal {
                    self.onFinal?(text)
                }
            }

            if let error {
                self.onError?(error)
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
    }

    func cancel() {
        stop()
        task?.cancel()
        task = nil
        request = nil
    }
}