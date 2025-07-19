// Message.swift

import Foundation

struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isMine: Bool
    let date: Date
}
