//
//  AudioSessionManager.swift
//  Apple Intelligence Chat
//
//  Created by Mahadik, Amit on 1/2/26.
//


import AVFoundation

final class AudioSessionManager {
    func configureForPTT() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .record,
            mode: .measurement,
            options: [.allowBluetoothHFP]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
