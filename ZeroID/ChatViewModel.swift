// ChatViewModel.swift

import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""

    let webrtc = WebRTCManager()
    
    private var cancellables = Set<AnyCancellable>()
    private var disconnectCleanupWorkItem: DispatchWorkItem?
    private var finalDisconnect: Bool = false

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
        // Реагируем и на изменение состояния ICE, чтобы поймать случаи убийства приложения на другой стороне
        webrtc.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self else { return }
                if connected {
                    // Отмена таймера очистки при восстановлении
                    self.disconnectCleanupWorkItem?.cancel()
                    self.disconnectCleanupWorkItem = nil
                    self.finalDisconnect = false
                } else {
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
        // Если уже запущен таймер — не создаем новый
        if disconnectCleanupWorkItem != nil { return }

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            print("[ChatViewModel] Disconnect grace timer fired, isConnected=\(self.webrtc.isConnected), finalDisconnect=\(self.finalDisconnect)")
            if !self.webrtc.isConnected && !self.finalDisconnect {
                self.messages.removeAll()
                self.finalDisconnect = true
            }
            self.disconnectCleanupWorkItem = nil
        }
        disconnectCleanupWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + graceSeconds, execute: work)
    }
}

