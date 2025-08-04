import Foundation
import SWCompression

// Утилиты для сериализации SDP через JSON → gzip → base64 пайплайн
// Совместимость с Rust ZeroID

struct SdpSerializer {
    
    // MARK: - GZIP сжатие/распаковка (используем SWCompression для совместимости с Rust)
    
    static func gzipCompress(_ data: Data) throws -> Data {
        return try GzipArchive.archive(data: data)
    }
    
    static func gzipDecompress(_ data: Data) throws -> Data {
        return try GzipArchive.unarchive(archive: data)
    }
    
    // MARK: - JSON сериализация/десериализация
    
    static func encodeSdpPayload(_ payload: SdpPayload) throws -> Data {
        return try JSONEncoder().encode(payload)
    }
    
    static func decodeSdpPayload(_ data: Data) throws -> SdpPayload {
        return try JSONDecoder().decode(SdpPayload.self, from: data)
    }
    
    static func encodeConnectionBundle(_ bundle: ConnectionBundle) throws -> Data {
        return try JSONEncoder().encode(bundle)
    }
    
    static func decodeConnectionBundle(_ data: Data) throws -> ConnectionBundle {
        return try JSONDecoder().decode(ConnectionBundle.self, from: data)
    }
    
    // MARK: - Base64 кодирование/декодирование
    
    static func base64Encode(_ data: Data) -> String {
        return data.base64EncodedString()
    }
    
    static func base64Decode(_ str: String) -> Data? {
        return Data(base64Encoded: str)
    }
    
    // MARK: - Полный пайплайн сериализации (Legacy API - только SdpPayload)
    
    static func serializeSdp(_ payload: SdpPayload) throws -> String {
        let json = try encodeSdpPayload(payload)
        let compressed = try gzipCompress(json)
        return base64Encode(compressed)
    }
    
    static func deserializeSdp(_ str: String) throws -> SdpPayload {
        guard let compressed = base64Decode(str) else {
            throw SdpSerializerError.invalidBase64
        }
        let json = try gzipDecompress(compressed)
        return try decodeSdpPayload(json)
    }
    
    // MARK: - Полный пайплайн сериализации (Новый API - ConnectionBundle)
    
    static func serializeBundle(_ bundle: ConnectionBundle) throws -> String {
        let json = try encodeConnectionBundle(bundle)
        let compressed = try gzipCompress(json)
        return base64Encode(compressed)
    }
    
    static func deserializeBundle(_ str: String) throws -> ConnectionBundle {
        guard let compressed = base64Decode(str) else {
            throw SdpSerializerError.invalidBase64
        }
        let json = try gzipDecompress(compressed)
        return try decodeConnectionBundle(json)
    }
    
    // MARK: - Автоматическое определение типа (Legacy vs New API)
    
    static func deserializeAuto(_ str: String) throws -> (sdpPayload: SdpPayload, iceCandidates: [IceCandidate]) {
        // Сначала пробуем как ConnectionBundle (новый API)
        do {
            let bundle = try deserializeBundle(str)
            return (bundle.sdp_payload, bundle.ice_candidates)
        } catch {
            // Если не получилось, пробуем как SdpPayload (legacy API)
            let payload = try deserializeSdp(str)
            return (payload, [])
        }
    }
}

// MARK: - Ошибки сериализации

enum SdpSerializerError: Error, LocalizedError {
    case compressionFailed
    case decompressionFailed
    case invalidBase64
    case invalidJson
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Ошибка сжатия данных"
        case .decompressionFailed:
            return "Ошибка распаковки данных"
        case .invalidBase64:
            return "Неверный формат base64"
        case .invalidJson:
            return "Неверный формат JSON"
        }
    }
} 