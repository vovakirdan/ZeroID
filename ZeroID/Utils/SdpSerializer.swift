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
    
    // MARK: - Base64 кодирование/декодирование
    
    static func base64Encode(_ data: Data) -> String {
        return data.base64EncodedString()
    }
    
    static func base64Decode(_ str: String) -> Data? {
        return Data(base64Encoded: str)
    }
    
    // MARK: - Полный пайплайн сериализации
    
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