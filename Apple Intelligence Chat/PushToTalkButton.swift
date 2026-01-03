//
//  PushToTalkButton.swift
//  Apple Intelligence Chat
//
//  Created by Mahadik, Amit on 1/2/26.
//


import SwiftUI

struct PushToTalkButton: View {
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: isActive
                      ? "waveform.circle.fill"
                      : "waveform.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(isActive ? "Listening…" : "PTT")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .accessibilityLabel(isActive ? "Stop listening" : "Start listening")
    }
}
