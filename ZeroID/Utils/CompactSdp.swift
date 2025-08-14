import Foundation
import SWCompression

// Компактные структуры и утилиты для совместимости с Rust-форматом "c:" и "cb:"

// MARK: - Compact Models

struct CompactSession: Codable {
    // t: 0 (offer), 1 (answer)
    // uf: ice-ufrag
    // up: ice-pwd
    // fp: DTLS fingerprint без двоеточий, UPPERCASE
    // sr: setup role: actpass=0, active=1, passive=2
    // mi: mid (обычно "0")
    // sp: sctp-port
    let t: Int
    let uf: String
    let up: String
    let fp: String
    let sr: Int
    let mi: String
    let sp: Int
}

struct CompactSdpPayload: Codable {
    let s: CompactSession
    let id: String
    let ts: Int64
}

struct CompactIceCandidate: Codable {
    // c: candidate string
    // md: sdpMid (optional)
    // ml: sdpMLineIndex (optional)
    // i: connectionId
    let c: String
    let md: String?
    let ml: Int?
    let i: String
}

struct CompactConnectionBundle: Codable {
    let s: CompactSdpPayload
    let cs: [CompactIceCandidate]
}

// MARK: - Regex helpers

private func firstMatch(pattern: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]) else { return nil }
    let range = NSRange(location: 0, length: (text as NSString).length)
    guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
    guard match.numberOfRanges > 1 else { return nil }
    let r = match.range(at: 1)
    guard let swiftRange = Range(r, in: text) else { return nil }
    return String(text[swiftRange])
}

// MARK: - Mapping helpers

private func setupStringToRole(_ setup: String) -> Int {
    let lower = setup.lowercased()
    if lower == "active" { return 1 }
    if lower == "passive" { return 2 }
    return 0 // actpass
}

private func roleToSetupString(_ role: Int) -> String {
    switch role {
    case 1: return "active"
    case 2: return "passive"
    default: return "actpass"
    }
}

private func insertColonsEveryTwoHex(_ hexNoColons: String) -> String {
    var result: [String] = []
    let chars = Array(hexNoColons)
    var i = 0
    while i < chars.count {
        let end = min(i+2, chars.count)
        result.append(String(chars[i..<end]))
        i += 2
    }
    return result.joined(separator: ":").uppercased()
}

// MARK: - Public API

enum CompactSdpError: Error {
    case invalidBase64
    case invalidGzip
    case invalidJson
    case invalidPrefix
    case missingField(String)
}

// Извлечь компактную сессию из SDP строки (после setLocalDescription)
func buildCompactPayload(from sdp: String, type: String, connectionId: String, timestamp: Int64) -> CompactSdpPayload {
    // Регулярные выражения
    let uf = firstMatch(pattern: #"a=ice-ufrag:(.+)"#, in: sdp) ?? ""
    let up = firstMatch(pattern: #"a=ice-pwd:(.+)"#, in: sdp) ?? ""
    let fpRaw = firstMatch(pattern: #"a=fingerprint:sha-256\s+([A-Fa-f0-9:]+)"#, in: sdp) ?? ""
    let fp = fpRaw.replacingOccurrences(of: ":", with: "").uppercased()
    let setupStr = firstMatch(pattern: #"a=setup:(actpass|active|passive)"#, in: sdp) ?? "actpass"
    let sr = setupStringToRole(setupStr)
    let mi = firstMatch(pattern: #"a=mid:(.+)"#, in: sdp) ?? "0"
    let spStr = firstMatch(pattern: #"a=sctp-port:(\\d+)"#, in: sdp) ?? firstMatch(pattern: #"a=sctpmap:(\\d+)\\b"#, in: sdp) ?? "5000"
    let sp = Int(spStr) ?? 5000
    let t = (type.lowercased() == "answer") ? 1 : 0

    let session = CompactSession(t: t, uf: uf, up: up, fp: fp, sr: sr, mi: mi, sp: sp)
    return CompactSdpPayload(s: session, id: connectionId, ts: timestamp)
}

// Сформировать SDP из компактной сессии по шаблону (идентично Rust)
func expandSdpFromCompact(_ compact: CompactSession) -> (type: String, sdp: String) {
    let t = compact.t == 1 ? "answer" : "offer"
    let fp = insertColonsEveryTwoHex(compact.fp)
    let setup = roleToSetupString(compact.sr)
    // Используем CRLF (\r\n) как в стандартном SDP; добавляем завершающую пустую строку
    let lines = [
        "v=0",
        "o=- 0 0 IN IP4 127.0.0.1",
        "s=-",
        "t=0 0",
        "a=group:BUNDLE {mid}",
        "a=msid-semantic: WMS",
        "m=application 9 UDP/DTLS/SCTP webrtc-datachannel",
        "c=IN IP4 0.0.0.0",
        "a=ice-ufrag:{uf}",
        "a=ice-pwd:{up}",
        "a=ice-options:trickle",
        "a=fingerprint:sha-256 {fp}",
        "a=setup:{setup}",
        "a=mid:{mid}",
        "a=sctp-port:{port}",
        "a=max-message-size:262144"
    ]
    var sdpStr = lines.joined(separator: "\r\n") + "\r\n"
    sdpStr = sdpStr
        .replacingOccurrences(of: "{mid}", with: compact.mi)
        .replacingOccurrences(of: "{uf}", with: compact.uf)
        .replacingOccurrences(of: "{up}", with: compact.up)
        .replacingOccurrences(of: "{fp}", with: fp)
        .replacingOccurrences(of: "{setup}", with: setup)
        .replacingOccurrences(of: "{port}", with: String(compact.sp))

    return (t, sdpStr)
}

// Кодирование одного компактного SDP: gzip+base64 c префиксом "c:"
func encodeCompactSdp(_ payload: CompactSdpPayload) throws -> String {
    let json = try JSONEncoder().encode(payload)
    let gz = try GzipArchive.archive(data: json)
    return "c:" + gz.base64EncodedString()
}

// Кодирование бандла компактных данных: gzip+base64 c префиксом "cb:"
func encodeCompactBundle(_ bundle: CompactConnectionBundle) throws -> String {
    let json = try JSONEncoder().encode(bundle)
    let gz = try GzipArchive.archive(data: json)
    return "cb:" + gz.base64EncodedString()
}

// Декодирование строки, начинающейся с "c:" → полный SDP и метаданные
func decodeCompactSdp(_ encoded: String) throws -> (payload: SdpPayload, candidates: [IceCandidate]) {
    guard encoded.hasPrefix("c:") else { throw CompactSdpError.invalidPrefix }
    let b64 = String(encoded.dropFirst(2))
    guard let gz = Data(base64Encoded: b64) else { throw CompactSdpError.invalidBase64 }
    let json = try GzipArchive.unarchive(archive: gz)
    let compact = try JSONDecoder().decode(CompactSdpPayload.self, from: json)
    let expanded = expandSdpFromCompact(compact.s)
    let sdpPayload = SdpPayload(sdp: expanded.sdp, type: expanded.type, id: compact.id, ts: compact.ts)
    return (sdpPayload, [])
}

// Декодирование строки, начинающейся с "cb:" → полный SDP и ICE кандидаты
func decodeCompactBundle(_ encoded: String) throws -> (payload: SdpPayload, candidates: [IceCandidate]) {
    guard encoded.hasPrefix("cb:") else { throw CompactSdpError.invalidPrefix }
    let b64 = String(encoded.dropFirst(3))
    guard let gz = Data(base64Encoded: b64) else { throw CompactSdpError.invalidBase64 }
    let json = try GzipArchive.unarchive(archive: gz)
    let compact = try JSONDecoder().decode(CompactConnectionBundle.self, from: json)
    let expanded = expandSdpFromCompact(compact.s.s)
    let sdpPayload = SdpPayload(sdp: expanded.sdp, type: expanded.type, id: compact.s.id, ts: compact.s.ts)
    let candidates: [IceCandidate] = compact.cs.map { c in
        IceCandidate(candidate: c.c, sdp_mid: c.md, sdp_mline_index: c.ml, connection_id: c.i)
    }
    return (sdpPayload, candidates)
}

// Универсальный декодер: определяет префикс и вызывает нужный декодер,
// либо падает обратно на старые схемы при отсутствии префикса
func decodeCompactAutoOrLegacy(_ encoded: String) throws -> (SdpPayload, [IceCandidate]) {
    if encoded.hasPrefix("cb:") { return try decodeCompactBundle(encoded) }
    if encoded.hasPrefix("c:") { return try decodeCompactSdp(encoded) }
    // Legacy пути
    return try SdpSerializer.deserializeAuto(encoded)
}


