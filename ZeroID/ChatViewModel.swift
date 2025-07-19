// ChatViewModel.swift

import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""

    let webrtc = WebRTCManager()
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        webrtc.$receivedMessage
            .sink { [weak self] text in
                guard !text.isEmpty else { return }
                self?.messages.append(Message(text: text, isMine: false, date: Date()))
            }
            .store(in: &cancellables)
    }

    func sendMessage() {
        guard !inputText.isEmpty else { return }
        webrtc.sendMessage(inputText)
        messages.append(Message(text: inputText, isMine: true, date: Date()))
        inputText = ""
    }
}

