//
//  ChatViewModel.swift
//  Apple Intelligence Chat
//
//  Created by Mahadik, Amit on 1/2/26.
//


//
//  ChatViewModel.swift
//  Apple Intelligence Chat
//

import Foundation
import FoundationModels
import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Push-to-Talk

    private let ptt = PushToTalkController()

    @Published var isListening: Bool = false

    /// Change to false if you want review-before-send
    private let autoSendOnStop = true
    
    
    // MARK: - Published UI State
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isResponding: Bool = false
    @Published var showSettings: Bool = false
    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String = ""

    // MARK: - Model State
    private var session: LanguageModelSession?
    private var streamingTask: Task<Void, Never>?
    private var model: SystemLanguageModel = .default

    // MARK: - Settings (persisted)
    @AppStorage("useStreaming") var useStreaming: Bool = AppSettings.useStreaming
    @AppStorage("temperature") var temperature: Double = AppSettings.temperature
    @AppStorage("systemInstructions") var systemInstructions: String = AppSettings.systemInstructions

    // MARK: - Haptics
    #if os(iOS)
    private let hapticStreamGenerator = UISelectionFeedbackGenerator()
    #endif

    // MARK: - Init

    init() {
        NotificationCenter.default.addObserver(
            forName: .togglePTTRequested,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.togglePTT()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        streamingTask?.cancel()
    }
    
    // MARK: - Tap-to-Toggle PTT

    func togglePTT() {
        // Do not start recording while model is responding
        guard !isResponding else { return }

        if isListening {
            stopPTT()
        } else {
            startPTT()
        }
    }

    private func startPTT() {
        isListening = true

        // Dismiss keyboard to reduce audio/gesture contention
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        #endif

        // Defer audio session work off the tap
        DispatchQueue.main.async {
            do {
                try self.ptt.startRecording()
            } catch {
                self.isListening = false
                self.showError(message: error.localizedDescription)
            }
        }
    }

    private func stopPTT() {
        guard isListening else { return }

        let transcript = ptt.stopRecording()
        isListening = false

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        inputText = trimmed

        if autoSendOnStop {
            handleSendOrStop()
        }
    }
    
    
    func preparePushToTalk() async {
        do {
            try await ptt.requestPermissions()
            // If you want, set a flag like hasMicPermission = true
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    

    
    // MARK: - Intent methods (called by the View)

    func handleSendOrStop() {
        if isListening {
            ptt.cancel()
            isListening = false
            return
        }

        if isResponding {
            stopStreaming()
            return
        }

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard model.isAvailable else {
            showError(message: "The language model is not available. Reason: \(availabilityDescription(for: model.availability))")
            return
        }

        sendMessage(prompt: trimmed)
    }

    func stopStreaming() {
        streamingTask?.cancel()
    }

    func resetConversation() {
        stopStreaming()
        messages.removeAll()
        session = nil
        isResponding = false
    }

    /// Call this from SettingsView’s “onChange”/dismiss callback.
    func resetSession() {
        session = nil
    }

    // MARK: - Core send / stream

    private func sendMessage(prompt: String) {
        // Optimistic UI update
        isResponding = true

        messages.append(ChatMessage(role: .user, text: prompt))
        inputText = ""

        // Placeholder assistant message (for streaming append)
        messages.append(ChatMessage(role: .assistant, text: ""))

        streamingTask = Task { [weak self] in
            guard let self else { return }

            defer {
                Task { @MainActor in
                    self.isResponding = false
                    self.streamingTask = nil
                }
            }

            do {
                if self.session == nil { self.session = self.createSession() }
                guard let currentSession = self.session else {
                    self.showError(message: "Session could not be created.")
                    return
                }

                let options = GenerationOptions(temperature: self.temperature)

                if self.useStreaming {
                    let stream = currentSession.streamResponse(to: prompt, options: options)

                    var lastAccumulated = ""

                    for try await snapshot in stream {
                        #if os(iOS)
                        self.hapticStreamGenerator.selectionChanged()
                        #endif

                        // Your current code uses snapshot.content; keep that for compatibility.
                        let accumulated = snapshot.content

                        // Compute delta
                        let delta: String
                        if accumulated.hasPrefix(lastAccumulated) {
                            delta = String(accumulated.dropFirst(lastAccumulated.count))
                        } else {
                            // Stream restarted/edited; replace entirely
                            self.replaceLastMessage(with: accumulated)
                            lastAccumulated = accumulated
                            continue
                        }

                        if !delta.isEmpty {
                            self.appendToLastMessage(delta)
                            lastAccumulated = accumulated
                        }
                    }
                } else {
                    let response = try await currentSession.respond(to: prompt, options: options)
                    self.replaceLastMessage(with: response.content)
                }
            } catch is CancellationError {
                // User cancelled generation; no-op
            } catch {
                self.showError(message: "An error occurred: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Message mutation helpers

    private func replaceLastMessage(with text: String) {
        guard !messages.isEmpty else { return }
        var last = messages.removeLast()
        last.text = text
        messages.append(last)
    }

    private func appendToLastMessage(_ text: String) {
        guard !messages.isEmpty else { return }
        var last = messages.removeLast()
        last.text += text
        messages.append(last)
    }

    // MARK: - Session & availability

    private func createSession() -> LanguageModelSession {
        LanguageModelSession(instructions: systemInstructions)
    }

    private func availabilityDescription(for availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            return "Available"
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "Device not eligible"
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence not enabled in Settings"
            case .modelNotReady:
                return "Model assets not downloaded"
            @unknown default:
                return "Unknown reason"
            }
        @unknown default:
            return "Unknown availability"
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showErrorAlert = true
        isResponding = false
    }
}
