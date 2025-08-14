// Message.swift

import Foundation

// Медиа-вложение к сообщению
struct MediaAttachment: Identifiable {
    let id: String
    let name: String
    let mime: String
    let size: Int
    var data: Data? = nil
    var progress: Double? = nil // 0.0..1.0 для исходящих
}

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isMine: Bool
    let date: Date
    var media: MediaAttachment? = nil
}
