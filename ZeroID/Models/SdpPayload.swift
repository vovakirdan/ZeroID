import Foundation

// Структура для совместимости с Rust RTCSessionDescription
struct RTCSessionDescriptionCodable: Codable {
    let type: String // "offer" или "answer"
    let sdp: String
    
    init(type: String, sdp: String) {
        self.type = type
        self.sdp = sdp
    }
}

// Структура для совместимости с Rust SdpPayload
struct SdpPayload: Codable {
    let sdp: RTCSessionDescriptionCodable
    let id: String
    let ts: Int64
    
    init(sdp: String, type: String, id: String, ts: Int64) {
        self.sdp = RTCSessionDescriptionCodable(type: type, sdp: sdp)
        self.id = id
        self.ts = ts
    }
    
    init(sdp: String, type: String) {
        self.sdp = RTCSessionDescriptionCodable(type: type, sdp: sdp)
        self.id = UUID().uuidString
        self.ts = Int64(Date().timeIntervalSince1970)
    }
    
    // Конструктор для обратной совместимости (Legacy API)
    init(sdp: String, id: String, ts: Int64) {
        self.sdp = RTCSessionDescriptionCodable(type: "unknown", sdp: sdp)
        self.id = id
        self.ts = ts
    }
    
    init(sdp: String) {
        self.sdp = RTCSessionDescriptionCodable(type: "unknown", sdp: sdp)
        self.id = UUID().uuidString
        self.ts = Int64(Date().timeIntervalSince1970)
    }
}

// Структура для ICE кандидатов (совместимость с Rust)
struct IceCandidate: Codable {
    let candidate: String
    let sdp_mid: String?
    let sdp_mline_index: Int? // Rust Option<u16> -> Swift Int?
    let connection_id: String
    
    init(candidate: String, sdp_mid: String? = nil, sdp_mline_index: Int? = nil, connection_id: String) {
        self.candidate = candidate
        self.sdp_mid = sdp_mid
        self.sdp_mline_index = sdp_mline_index
        self.connection_id = connection_id
    }
}

// Структура для совместимости с Rust ConnectionBundle
struct ConnectionBundle: Codable {
    let sdp_payload: SdpPayload
    let ice_candidates: [IceCandidate]
    
    init(sdp_payload: SdpPayload, ice_candidates: [IceCandidate] = []) {
        self.sdp_payload = sdp_payload
        self.ice_candidates = ice_candidates
    }
} 