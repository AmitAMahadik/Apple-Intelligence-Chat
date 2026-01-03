//
//  ChatView.swift
//  Apple Intelligence Chat
//

import SwiftUI

struct ChatView: View {

    @StateObject private var vm = ChatViewModel()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        ForEach(vm.messages) { message in
                            MessageView(message: message, isResponding: vm.isResponding)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: vm.messages.last?.text) {
                    if let last = vm.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("Apple Intelligence Chat")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .sheet(isPresented: $vm.showSettings) {
                SettingsView {
                    vm.resetSession()
                }
            }
            .alert("Error", isPresented: $vm.showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(vm.errorMessage)
            }
            // ✅ FIX: attach the composer using safeAreaInset (keyboard-friendly)
            .safeAreaInset(edge: .bottom) {
                inputField
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .background(.clear)
            }
        }
        .task {
            await vm.preparePushToTalk()
        }
    }

    
    // MARK: - Input Field

    private var inputField: some View {
        ZStack {
            TextField("Ask anything", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .frame(minHeight: 22)
                .disabled(vm.isResponding)
                .onSubmit {
                    let trimmed = vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty || vm.isResponding {
                        vm.handleSendOrStop()
                    }
                }
                .padding(16)

            HStack(spacing: 10) {
                Spacer()

                // Distinct in-app PTT button (optional wiring)
                PushToTalkButton(
                    isActive: vm.isListening,
                    onTap: { vm.togglePTT() }
                )
                .padding(.trailing, 2)

                Button(action: vm.handleSendOrStop) {
                    Image(systemName: vm.isResponding ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(isSendButtonDisabled ? Color.gray.opacity(0.6) : .primary)
                }
                .disabled(isSendButtonDisabled)
                .animation(.easeInOut(duration: 0.2), value: vm.isResponding)
                .animation(.easeInOut(duration: 0.2), value: isSendButtonDisabled)
                .glassEffect(.regular.interactive())
                .padding(.trailing, 8)
            }
        }
        .glassEffect(.regular.interactive())
    }

    private var isSendButtonDisabled: Bool {
        vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isResponding
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: vm.resetConversation) {
                Label("New Chat", systemImage: "square.and.pencil")
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { vm.showSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }
        }
        #else
        ToolbarItem {
            Button(action: vm.resetConversation) {
                Label("New Chat", systemImage: "square.and.pencil")
            }
        }
        ToolbarItem {
            Button(action: { vm.showSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }
        }
        #endif
    }
}

#Preview {
    ChatView()
}
