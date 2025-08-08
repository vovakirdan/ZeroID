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
                // Добавляем время к логу для отладки
                let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString)] [ChatViewModel] Received message:", text)
                self?.messages.append(Message(text: text, isMine: false, date: Date()))
            }
            .store(in: &cancellables)

        // Очистка сообщений при отключении/сбросе соединения
        webrtc.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self else { return }
                if !connected {
                    // Запускаем таймер ожидания восстановления соединения
                    self.scheduleDisconnectCleanup()
                }
            }
            .store(in: &cancellables)
    }

    func sendMessage() {
        guard !inputText.isEmpty else { return }
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [ChatViewModel] Sending message:", inputText)
        webrtc.sendMessage(inputText)
        messages.append(Message(text: inputText, isMine: true, date: Date()))
        inputText = ""
    }

    // Явная очистка истории (при выходе из диалога)
    func clearMessages() {
        messages.removeAll()
    }

    // План очистки при дисконнекте, если не восстановились за 10 сек
    private func scheduleDisconnectCleanup() {
        let graceSeconds: Double = 10
        let currentConnectionSnapshot = webrtc.isConnected
        DispatchQueue.main.asyncAfter(deadline: .now() + graceSeconds) { [weak self] in
            guard let self else { return }
            // Если за время ожидания соединение не восстановилось — чистим историю
            if !self.webrtc.isConnected && !currentConnectionSnapshot {
                print("[ChatViewModel] Connection not restored for \(graceSeconds)s — clearing messages")
                self.messages.removeAll()
            }
        }
    }
}

