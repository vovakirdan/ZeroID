// ChatViewModel.swift

import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false

    let webrtc = WebRTCManager()
    
    private var cancellables = Set<AnyCancellable>()
    private var disconnectCleanupWorkItem: DispatchWorkItem?
    private var finalDisconnect: Bool = false

    init() {
        // Подписка на входящие текстовые сообщения
        webrtc.$receivedMessage
            .sink { [weak self] text in
                guard !text.isEmpty else { return }
                // Добавляем время к логу для отладки
                let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString)] [ChatViewModel] Received message:", text)
                self?.messages.append(Message(text: text, isMine: false, date: Date()))
            }
            .store(in: &cancellables)

        // Подписка на входящие медиа
        webrtc.onMediaReceived = { [weak self] media in
            guard let self else { return }
            DispatchQueue.main.async {
                self.messages.append(Message(text: "", isMine: false, date: Date(), media: media))
            }
        }

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

    // Отправка медиа-файла с прогрессом
    func sendFile(url: URL) {
        // Создаем локальное сообщение с прогрессом
        let fileName = url.lastPathComponent
        let mime = ChatViewModel.mimeType(for: url)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        let id = "\(Int(Date().timeIntervalSince1970))-\(fileName)"
        let attachment = MediaAttachment(id: id, name: fileName, mime: mime, size: size, data: nil, progress: 0)
        let msgIndex = messages.count
        messages.append(Message(text: "", isMine: true, date: Date(), media: attachment))

        // Предпросмотр локально (например, изображения)
        if let data = try? Data(contentsOf: url) {
            if messages.indices.contains(msgIndex), var media = messages[msgIndex].media {
                media.data = data
                messages[msgIndex].media = media
            }
        }

        webrtc.sendMediaFile(id: id, url: url, name: fileName, mime: mime) { [weak self] progress in
            guard let self else { return }
            DispatchQueue.main.async {
                if self.messages.indices.contains(msgIndex), var media = self.messages[msgIndex].media {
                    media.progress = progress
                    self.messages[msgIndex].media = media
                }
            }
        } completion: { [weak self] success in
            guard let self else { return }
            DispatchQueue.main.async {
                if !success {
                    // Удаляем сообщение при ошибке
                    self.messages.removeAll { $0.media?.id == id }
                } else {
                    // Финальный прогресс 1.0
                    if let idx = self.messages.firstIndex(where: { $0.media?.id == id }) {
                        self.messages[idx].media?.progress = 1.0
                    }
                }
            }
        }
    }

    private static func mimeType(for url: URL) -> String {
        // Простое определение по расширению
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        default: return "application/octet-stream"
        }
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

