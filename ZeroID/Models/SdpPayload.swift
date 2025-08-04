import Foundation

// Структура для совместимости с Rust SdpPayload
struct SdpPayload: Codable {
    let sdp: String
    let id: String
    let ts: Int64
    
    init(sdp: String, id: String, ts: Int64) {
        self.sdp = sdp
        self.id = id
        self.ts = ts
    }
    
    // Конструктор с автоматической генерацией id и timestamp
    init(sdp: String) {
        self.sdp = sdp
        self.id = UUID().uuidString
        self.ts = Int64(Date().timeIntervalSince1970)
    }
} 