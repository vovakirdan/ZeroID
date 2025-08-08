// WebRTCManager.swift

import Foundation
import WebRTC
import CryptoKit

// Криптографический контекст для шифрования сообщений
struct CryptoContext {
    let sealingKey: SymmetricKey
    let openingKey: SymmetricKey
    var sendNonce: UInt64 = 1
    var recvNonce: UInt64 = 1
    var lastAcceptedRecv: UInt64 = 0
    let sas: String
}

// Расширение: конвертация UInt64 → 12-байтовый nonce (как в Rust: первые 4 байта нули, далее 8 байт big-endian)
extension UInt64 {
    func toChaChaNonceData() -> Data {
        let be = self.bigEndian
        let tail = withUnsafeBytes(of: be) { Data($0) } // 8 байт
        return Data([0,0,0,0]) + tail // всего 12 байт
    }
}

// Состояния сверки отпечатков
enum FingerprintVerificationState {
    case notStarted
    case waitingForPeerPubkey
    case pubkeyReceived
    case verificationRequired
    case verified
    case failed
}

class WebRTCManager: NSObject, ObservableObject {
    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var factory: RTCPeerConnectionFactory
    
    // Криптографические ключи для X25519
    private var myPrivateKey: Curve25519.KeyAgreement.PrivateKey?
    private var cryptoContext: CryptoContext?
    private var pendingPeerPubKey: String? // Буфер для входящего ключа если наш еще не готов
    
    // Completion handlers для ожидания завершения ICE gathering
    private var offerCompletion: ((String?) -> Void)?
    private var answerCompletion: ((String?) -> Void)?
    
    // Состояние для оптимизированного сбора кандидатов
    private var gatherStartTime: Date?
    private var hasRelayCandidate: Bool = false
    private var internalCandidateCount: Int = 0
    private let iceServers = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun2.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun3.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun4.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["turn:relay1.expressturn.com:3480"],
                     username: "000000002067703673",
                     credential: "aUS5WkBI4dk568G6L/uv7ZQvBAQ=")
    ]

    // Сбор ICE-кандидатов для ConnectionBundle
    private var collectedIceCandidates: [IceCandidate] = []
    private var currentConnectionId: String? = nil

    // Состояние сверки отпечатков
    @Published var fingerprintVerificationState: FingerprintVerificationState = .notStarted
    @Published var myPubKey: String = ""
    @Published var peerPubKey: String = ""
    @Published var myFingerprint: String = ""
    @Published var peerFingerprint: String = ""
    @Published var isChatEnabled: Bool = false
    // SAS-код для отображения пользователю (нижний регистр, 12 hex символов)
    @Published var sasCode: String = ""

    @Published var receivedMessage: String = ""
    @Published var isConnected: Bool = false
    @Published var dataChannelState: String = "не создан"
    @Published var iceConnectionState: String = "не создан"
    @Published var iceGatheringState: String = "не создан"
    @Published var candidateCount: String = "0"
    private let tagLen: Int = 16 // длина тега Poly1305

    override init() {
        print("[WebRTCManager] Init")
        
        // Запускаем тесты сериализации при инициализации
        #if DEBUG
        SdpSerializerTests.testSerializationPipeline()
        SdpSerializerTests.testConnectionBundlePipeline()
        SdpSerializerTests.testAutoDetection()
        SdpSerializerTests.testCompressionRatio()
        #endif
        
        RTCInitializeSSL()
        self.factory = RTCPeerConnectionFactory()
        super.init()
    }

    // Явный сброс и закрытие соединения
    func resetConnection() {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Reset connection invoked")

        // Закрываем канал данных
        if let dc = dataChannel {
            dc.close()
        }
        dataChannel = nil

        // Закрываем peer connection
        if let pc = peerConnection {
            pc.close()
        }
        peerConnection = nil

        // Сбрасываем крипто и служебные состояния
        myPrivateKey = nil
        cryptoContext = nil
        pendingPeerPubKey = nil
        offerCompletion = nil
        answerCompletion = nil
        gatherStartTime = nil
        hasRelayCandidate = false
        internalCandidateCount = 0
        collectedIceCandidates.removeAll()
        currentConnectionId = nil

        DispatchQueue.main.async {
            self.fingerprintVerificationState = .notStarted
            self.myPubKey = ""
            self.peerPubKey = ""
            self.myFingerprint = ""
            self.peerFingerprint = ""
            self.sasCode = ""
            self.isChatEnabled = false
            self.isConnected = false
            self.dataChannelState = "не создан"
            self.iceConnectionState = "не создан"
            self.iceGatheringState = "не создан"
            self.candidateCount = "0"
        }
    }

    // Создание peerConnection
    func createPeerConnection() -> RTCPeerConnection {
        print("[WebRTC] Creating peerConnection")
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.continualGatheringPolicy = .gatherContinually
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString)] [WebRTC] ERROR: Failed to create RTCPeerConnection")
            fatalError("Failed to create RTCPeerConnection")
        }
        self.peerConnection = pc
        let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString2)] [WebRTC] PeerConnection created successfully")
        return pc
    }

    // MARK: - Fingerprint Verification
    
    // Парсинг DTLS fingerprint из SDP строки
    private func parseFingerprint(from sdp: String) -> String? {
        // Ищем строку вида a=fingerprint:sha-256 AA:BB:CC:...
        let pattern = #"a=fingerprint:sha-256 ([A-F0-9:]+)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: sdp, options: [], range: NSRange(location: 0, length: sdp.utf16.count)),
           let range = Range(match.range(at: 1), in: sdp) {
            return String(sdp[range])
        }
        return nil
    }
    
    // Генерация X25519 ключевой пары
    private func generateX25519KeyPair() -> (privateKey: Curve25519.KeyAgreement.PrivateKey, publicKeyBase64: String) {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKeyData = privateKey.publicKey.rawRepresentation
        let publicKeyBase64 = publicKeyData.base64EncodedString()
        
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Generated X25519 keypair, pubkey length:", publicKeyData.count)
        
        return (privateKey, publicKeyBase64)
    }
    
    // Получение DTLS fingerprint от remote peer
    private func getRemoteFingerprint() -> String? {
        guard let peerConnection = peerConnection,
              let remoteSdp = peerConnection.remoteDescription?.sdp else { 
            return nil 
        }
        
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Getting remote fingerprint from SDP...")
        
        // Парсим fingerprint из remote SDP
        if let fingerprint = parseFingerprint(from: remoteSdp) {
            print("[\(timeString)] [WebRTC] Remote fingerprint found: \(fingerprint)")
            return fingerprint
        } else {
            print("[\(timeString)] [WebRTC] ERROR: No fingerprint found in remote SDP")
            return nil
        }
    }
    
    // Получение локального DTLS fingerprint
    private func getLocalFingerprint() -> String? {
        guard let peerConnection = peerConnection,
              let localSdp = peerConnection.localDescription?.sdp else { 
            return nil 
        }
        
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Getting local fingerprint from SDP...")
        
        // Парсим fingerprint из local SDP
        if let fingerprint = parseFingerprint(from: localSdp) {
            print("[\(timeString)] [WebRTC] Local fingerprint found: \(fingerprint)")
            return fingerprint
        } else {
            print("[\(timeString)] [WebRTC] ERROR: No fingerprint found in local SDP")
            return nil
        }
    }
    
    // Отправка pubkey через data channel
    private func sendPubKey() {
        guard let dc = dataChannel else {
            let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString)] [WebRTC] ERROR: DataChannel is nil")
            return
        }
        
        // Проверяем состояние DataChannel
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] DataChannel state before sending pubkey:", dc.readyState.rawValue)
        
        guard dc.readyState == .open else {
            print("[\(timeString)] [WebRTC] ERROR: DataChannel not ready for sending pubkey, state:", dc.readyState.rawValue)
            return
        }
        
        // Генерируем X25519 ключевую пару если еще не сгенерирована
        let pubKeyBase64: String
        if let existingPrivateKey = myPrivateKey {
            // Используем уже сгенерированный ключ
            pubKeyBase64 = myPubKey
            print("[\(timeString)] [WebRTC] Using existing X25519 keypair")
        } else {
            // Генерируем новую пару
            let (privateKey, newPubKeyBase64) = generateX25519KeyPair()
            myPrivateKey = privateKey
            myPubKey = newPubKeyBase64
            pubKeyBase64 = newPubKeyBase64
            print("[\(timeString)] [WebRTC] Generated new X25519 keypair")
        }
        
        let message = "PUBKEY:" + pubKeyBase64
        let buffer = RTCDataBuffer(data: message.data(using: .utf8)!, isBinary: false)
        let success = dc.sendData(buffer)
        
        if success {
            print("[\(timeString)] [WebRTC] Successfully sent X25519 pubkey:", pubKeyBase64)
            
            // Переходим в состояние ожидания pubkey от peer
            DispatchQueue.main.async {
                print("[\(timeString)] [WebRTC] Setting verification state to .waitingForPeerPubkey")
                self.fingerprintVerificationState = .waitingForPeerPubkey
                print("[\(timeString)] [WebRTC] Current verification state: \(self.fingerprintVerificationState)")
            }
        } else {
            print("[\(timeString)] [WebRTC] ERROR: Failed to send pubkey")
        }
    }
    
    // Обработка полученного pubkey и создание криптографического контекста
    private func handleReceivedPubKey(_ pubKeyBase64: String) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Processing received pubkey, length:", pubKeyBase64.count)
        print("[\(timeString)] [WebRTC] Received pubkey:", pubKeyBase64)
        
        // Проверяем, что pubkey не пустой
        guard !pubKeyBase64.isEmpty else {
            print("[\(timeString)] [WebRTC] ERROR: Received empty pubkey")
            return
        }
        
        // Проверяем, что у нас есть приватный ключ
        guard let myPrivateKey = myPrivateKey else {
            print("[\(timeString)] [WebRTC] Private key not ready yet, buffering peer pubkey")
            pendingPeerPubKey = pubKeyBase64
            return
        }
        
        // Очищаем буфер если он был использован
        pendingPeerPubKey = nil
        
        // Декодируем base64 pubkey
        guard let peerPubKeyData = Data(base64Encoded: pubKeyBase64),
              peerPubKeyData.count == 32 else {
            print("[\(timeString)] [WebRTC] ERROR: Invalid pubkey format or length")
            return
        }
        
        do {
            // Создаем публичный ключ из полученных данных
            let peerPublicKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPubKeyData)
            
            // Выполняем key agreement для получения общего секрета
            let sharedSecret = try myPrivateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
            
            // Создаем криптографический контекст
            let context = createCryptoContext(from: sharedSecret, myPubKey: myPubKey, peerPubKey: pubKeyBase64)
            self.cryptoContext = context
            
            peerPubKey = pubKeyBase64
            
            // Получаем DTLS fingerprint обеих сторон
            if let localFingerprint = getLocalFingerprint() {
                myFingerprint = localFingerprint
                print("[\(timeString)] [WebRTC] Local DTLS fingerprint set: \(localFingerprint)")
            } else {
                // Если нет DTLS fingerprint, используем SAS
                myFingerprint = "SAS: \(context.sas)"
                print("[\(timeString)] [WebRTC] Using SAS as local fingerprint: \(context.sas)")
            }
            
            if let remoteFingerprint = getRemoteFingerprint() {
                peerFingerprint = remoteFingerprint
                print("[\(timeString)] [WebRTC] Remote DTLS fingerprint set: \(remoteFingerprint)")
            } else {
                // Если нет DTLS fingerprint, используем SAS
                peerFingerprint = "SAS: \(context.sas)"
                print("[\(timeString)] [WebRTC] Using SAS as remote fingerprint: \(context.sas)")
            }
            
            print("[\(timeString)] [WebRTC] Crypto context created successfully")
            print("[\(timeString)] [WebRTC] SAS generated:", context.sas)
            
            // Переходим в состояние ожидания подтверждения
            DispatchQueue.main.async {
                print("[\(timeString)] [WebRTC] Setting verification state to .verificationRequired")
                self.fingerprintVerificationState = .verificationRequired
                print("[\(timeString)] [WebRTC] Current verification state: \(self.fingerprintVerificationState)")
            }
            
        } catch {
            print("[\(timeString)] [WebRTC] ERROR creating crypto context:", error)
            DispatchQueue.main.async {
                self.fingerprintVerificationState = .failed
            }
        }
    }
    
    // Создание криптографического контекста из общего секрета
    private func createCryptoContext(from sharedSecret: SharedSecret, myPubKey: String, peerPubKey: String) -> CryptoContext {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        
        // Создаем HKDF для получения ключей шифрования (как в Rust)
        let salt = Data() // Пустая соль для совместимости с Rust
        let info = "ssc-chat".data(using: .utf8)!
        
        let derivedKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: info,
            outputByteCount: 64 // 32 байта для каждого ключа
        )
        
        // Разделяем ключи
        let keyData = derivedKey.withUnsafeBytes { Data($0) }
        let k1 = keyData.prefix(32)
        let k2 = keyData.suffix(32)
        
        // Детерминированно выбираем ключи на основе лексикографического сравнения байтов публичных ключей (как в Rust)
        let myPubBytes = Data(base64Encoded: myPubKey) ?? Data()
        let peerPubBytes = Data(base64Encoded: peerPubKey) ?? Data()
        let (sendKeyData, recvKeyData) = (myPubBytes.lexicographicallyPrecedes(peerPubBytes)) ? (k1, k2) : (k2, k1)
        
        let sealingKey = SymmetricKey(data: sendKeyData)
        let openingKey = SymmetricKey(data: recvKeyData)
        
        // Генерируем SAS из первого ключа (как в Rust): sha256(k1) → первые 6 байт → 12 hex НИЖНИМ регистром
        let sasData = SHA256.hash(data: k1)
        let sasHexLower = sasData.prefix(6).map { String(format: "%02x", $0) }.joined()
        
        print("[\(timeString)] [WebRTC] Created crypto context - SAS:", sasHexLower)
        DispatchQueue.main.async { self.sasCode = sasHexLower }
        
        return CryptoContext(
            sealingKey: sealingKey,
            openingKey: openingKey,
            sas: sasHexLower
        )
    }
    
    // Подтверждение сверки отпечатков
    func confirmFingerprintVerification() {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] SAS verification confirmed")
        
        guard cryptoContext != nil else {
            print("[\(timeString)] [WebRTC] ERROR: No crypto context available")
            return
        }
        
        DispatchQueue.main.async {
            self.fingerprintVerificationState = .verified
            self.isChatEnabled = true
        }
    }
    
    // Отклонение сверки отпечатков
    func rejectFingerprintVerification() {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] SAS verification rejected")
        
        // Сбрасываем криптографический контекст
        cryptoContext = nil
        myPrivateKey = nil
        
        DispatchQueue.main.async {
            self.fingerprintVerificationState = .failed
            self.isChatEnabled = false
            self.myFingerprint = ""
            self.peerFingerprint = ""
        }
    }

    // Создать оффер (инициатор)
    func createOffer(completion: @escaping (String?) -> Void) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Initiator: creating offer")
        
        // Генерируем connection ID для текущего соединения
        self.currentConnectionId = UUID().uuidString
        print("[\(timeString)] [WebRTC] Generated connection ID:", self.currentConnectionId ?? "nil")
        
        // Очищаем старые кандидаты
        self.collectedIceCandidates.removeAll()
        
        // Инициализируем состояние сбора кандидатов
        self.gatherStartTime = Date()
        self.hasRelayCandidate = false
        self.internalCandidateCount = 0
        DispatchQueue.main.async {
            self.candidateCount = "0"
        }
        
        // Сохраняем completion handler для ожидания завершения ICE gathering
        self.offerCompletion = completion
        
        // Резервный таймер на 2.6 секунды для отдачи SDP
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            guard let self = self,
                  let pc = self.peerConnection,
                  self.offerCompletion != nil else { return }
            let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString)] [WebRTC] Timer triggered - checking readiness again")
            self.checkIfReadyToReturnSDP(pc)
        }
        
        self.peerConnection = createPeerConnection()
        let dataChannelConfig = RTCDataChannelConfiguration()
        let dc = peerConnection!.dataChannel(forLabel: "chat", configuration: dataChannelConfig)
        dc?.delegate = self
        self.dataChannel = dc
        let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString2)] [WebRTC] DataChannel (initiator) created, readyState:", dc?.readyState.rawValue ?? -1)
        DispatchQueue.main.async {
            self.dataChannelState = "создан (инициатор): \(dc?.readyState.rawValue ?? -1)"
        }

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            if let error = error {
                print("[\(timeString3)] [WebRTC] ERROR creating offer:", error)
                completion(nil)
                return
            }
            guard let sdp = sdp else { 
                print("[\(timeString3)] [WebRTC] ERROR: SDP is nil")
                completion(nil)
                return 
            }
            print("[\(timeString3)] [WebRTC] Offer created successfully")
            self?.peerConnection?.setLocalDescription(sdp, completionHandler: { err in
                let timeString4 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                if let err = err {
                    print("[\(timeString4)] [WebRTC] ERROR setting local description:", err)
                } else {
                    print("[\(timeString4)] [WebRTC] Local description set successfully")
                }
                // НЕ вызываем completion здесь - ждем достаточного количества кандидатов
            })
        }
    }

    // Принять remote offer, создать answer
    func receiveOffer(_ offerSDP: String, completion: @escaping (String?) -> Void) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Receiver: received offer, deserializing...")
        
        // Инициализируем состояние сбора кандидатов
        self.gatherStartTime = Date()
        self.hasRelayCandidate = false
        self.internalCandidateCount = 0
        DispatchQueue.main.async {
            self.candidateCount = "0"
        }
        
        // Сохраняем completion handler для ожидания завершения ICE gathering
        self.answerCompletion = completion
        
        // Резервный таймер на 2.6 секунды для отдачи SDP
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            guard let self = self,
                  let pc = self.peerConnection,
                  self.answerCompletion != nil else { return }
            let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString)] [WebRTC] Timer triggered - checking readiness again")
            self.checkIfReadyToReturnSDP(pc)
        }
        
        // Десериализуем SDP с автоматическим определением типа (Legacy vs New API)
        do {
            let (payload, iceCandidates) = try SdpSerializer.deserializeAuto(offerSDP)
            print("[\(timeString)] [WebRTC] Deserialized offer payload - id:", payload.id, "ts:", payload.ts)
            print("[\(timeString)] [WebRTC] Offer SDP type:", payload.sdp.type)
            print("[\(timeString)] [WebRTC] Offer SDP length:", payload.sdp.sdp.count)
            print("[\(timeString)] [WebRTC] ICE candidates count:", iceCandidates.count)
            
            // Устанавливаем connection ID из полученного payload
            self.currentConnectionId = payload.id
            print("[\(timeString)] [WebRTC] Using connection ID from offer:", self.currentConnectionId ?? "nil")
            
            // Очищаем старые кандидаты
            self.collectedIceCandidates.removeAll()
            
            if payload.sdp.sdp.isEmpty {
                let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString2)] [WebRTC] ERROR: Deserialized SDP is empty")
                completion(nil)
                return
            }
            
            // Проверяем, что SDP начинается с правильного формата
            if !payload.sdp.sdp.hasPrefix("v=0") {
                let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString2)] [WebRTC] ERROR: Deserialized SDP has invalid format (should start with 'v=0')")
                print("[\(timeString2)] [WebRTC] SDP starts with:", String(payload.sdp.sdp.prefix(10)))
                completion(nil)
                return
            }
            
            // Детальное логирование SDP для диагностики
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] Offer SDP content (first 100 chars):", String(payload.sdp.sdp.prefix(100)))
            
            self.peerConnection = createPeerConnection()
            let sdp = RTCSessionDescription(type: .offer, sdp: payload.sdp.sdp)
            
            // Применяем полученные ICE-кандидаты после установки remote description
            for candidate in iceCandidates {
                print("[\(timeString)] [WebRTC] Applying remote ICE candidate:", candidate.candidate)
                let rtcCandidate = RTCIceCandidate(
                    sdp: candidate.candidate,
                    sdpMLineIndex: Int32(candidate.sdp_mline_index ?? 0),
                    sdpMid: candidate.sdp_mid
                )
                peerConnection?.add(rtcCandidate) { error in
                    if let error = error {
                        let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                        print("[\(timeString2)] [WebRTC] ERROR adding ICE candidate:", error)
                    }
                }
            }
            
            peerConnection?.setRemoteDescription(sdp, completionHandler: { [weak self] error in
                let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                if let error = error {
                    print("[\(timeString3)] [WebRTC] ERROR setting remote description:", error)
                    completion(nil)
                    return
                }
                print("[\(timeString3)] [WebRTC] Remote description set successfully")
                
                // Создаем answer
                let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
                self?.peerConnection?.answer(for: constraints) { answerSdp, error in
                    let timeString4 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                    if let error = error {
                        print("[\(timeString4)] [WebRTC] ERROR creating answer:", error)
                        completion(nil)
                        return
                    }
                    guard let answerSdp = answerSdp else {
                        print("[\(timeString4)] [WebRTC] ERROR: Answer SDP is nil")
                        completion(nil)
                        return
                    }
                    print("[\(timeString4)] [WebRTC] Answer created successfully")
                    
                    self?.peerConnection?.setLocalDescription(answerSdp, completionHandler: { err2 in
                        let timeString5 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                        if let err2 = err2 {
                            print("[\(timeString5)] [WebRTC] ERROR setting local answer description:", err2)
                        } else {
                            print("[\(timeString5)] [WebRTC] Local answer description set successfully")
                        }
                        // НЕ вызываем completion здесь - ждем завершения ICE gathering
                    })
                }
            })
        } catch {
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] ERROR deserializing offer:", error)
            completion(nil)
            return
        }
    }

    // Принять answer на стороне инициатора
    func receiveAnswer(_ answerSDP: String) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Initiator: received answer, deserializing...")
        
        // Десериализуем SDP с автоматическим определением типа (Legacy vs New API)
        do {
            let (payload, iceCandidates) = try SdpSerializer.deserializeAuto(answerSDP)
            print("[\(timeString)] [WebRTC] Deserialized answer payload - id:", payload.id, "ts:", payload.ts)
            print("[\(timeString)] [WebRTC] Answer SDP length:", payload.sdp.sdp.count)
            print("[\(timeString)] [WebRTC] ICE candidates count:", iceCandidates.count)
            
            if payload.sdp.sdp.isEmpty {
                let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString2)] [WebRTC] ERROR: Deserialized SDP is empty")
                return
            }
            
            // Проверяем, что SDP начинается с правильного формата
            if !payload.sdp.sdp.hasPrefix("v=0") {
                let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString3)] [WebRTC] ERROR: Deserialized SDP has invalid format (should start with 'v=0')")
                print("[\(timeString3)] [WebRTC] SDP starts with:", String(payload.sdp.sdp.prefix(10)))
                return
            }
            
            // Детальное логирование SDP для диагностики
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] Answer SDP content (first 100 chars):", String(payload.sdp.sdp.prefix(100)))
            
            guard let pc = self.peerConnection else { 
                let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString3)] [WebRTC] ERROR: No peer connection for answer")
                return 
            }
            
            let sdp = RTCSessionDescription(type: .answer, sdp: payload.sdp.sdp)
            
            // Применяем полученные ICE-кандидаты
            for candidate in iceCandidates {
                print("[\(timeString)] [WebRTC] Applying remote ICE candidate from answer:", candidate.candidate)
                let rtcCandidate = RTCIceCandidate(
                    sdp: candidate.candidate,
                    sdpMLineIndex: Int32(candidate.sdp_mline_index ?? 0),
                    sdpMid: candidate.sdp_mid
                )
                pc.add(rtcCandidate) { error in
                    if let error = error {
                        let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                        print("[\(timeString2)] [WebRTC] ERROR adding ICE candidate from answer:", error)
                    }
                }
            }
            
            pc.setRemoteDescription(sdp, completionHandler: { err in
                let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                if let err = err {
                    print("[\(timeString3)] [WebRTC] ERROR setting remote answer description:", err)
                } else {
                    print("[\(timeString3)] [WebRTC] Remote answer description set successfully")
                }
            })
        } catch {
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] ERROR deserializing answer:", error)
            return
        }
    }

    // Отправка зашифрованного сообщения через dataChannel
    func sendMessage(_ text: String) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Sending message:", text)
        
        // Проверяем, что сверка отпечатков завершена
        guard fingerprintVerificationState == .verified else {
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] ERROR: Cannot send message - SAS not verified")
            return
        }
        
        guard let dc = dataChannel, dc.readyState == .open else { 
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] ERROR: DataChannel not ready, state:", dataChannel?.readyState.rawValue ?? -1)
            return 
        }
        
        guard var context = cryptoContext else {
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] ERROR: No crypto context available")
            return
        }
        
        do {
            // Шифруем сообщение ChaCha20-Poly1305 (совместимо с Rust)
            let messageData = text.data(using: .utf8)!
            let nonce = try ChaChaPoly.Nonce(data: context.sendNonce.toChaChaNonceData())
            let sealedBox = try ChaChaPoly.seal(messageData, using: context.sealingKey, nonce: nonce)
            let encryptedData = sealedBox.ciphertext + sealedBox.tag // без nonce, как в Rust
            
            // Отправляем зашифрованные данные
            let buffer = RTCDataBuffer(data: encryptedData, isBinary: true)
            let success = dc.sendData(buffer)
            
            if success {
                // Увеличиваем nonce для следующего сообщения
                context.sendNonce += 1
                self.cryptoContext = context
                let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString3)] [WebRTC] Encrypted message sent successfully, nonce:", context.sendNonce)
            } else {
                let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString3)] [WebRTC] ERROR: Failed to send encrypted message")
            }
        } catch {
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] ERROR encrypting message:", error)
        }
    }
    
    // Проверка готовности для отдачи SDP
    private func checkIfReadyToReturnSDP(_ peerConnection: RTCPeerConnection) {
        guard let startTime = gatherStartTime else { return }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let hasAnyCandidate = internalCandidateCount > 0
        
        // Условия готовности:
        // 1. Есть relay кандидат (TURN) - отдаем сразу
        // 2. Прошло 2.5 секунды и есть хотя бы один кандидат
        let isReady = hasRelayCandidate || (elapsedTime > 2.5 && hasAnyCandidate)
        
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Checking readiness: elapsed=\(elapsedTime)s, candidates=\(internalCandidateCount), relay=\(hasRelayCandidate), ready=\(isReady)")
        
        if isReady {
            // Для offer
            if let offerCompletion, peerConnection.localDescription?.type == .offer {
                let sdp = peerConnection.localDescription?.sdp
                if let sdp = sdp {
                    // Сериализуем ConnectionBundle через JSON → gzip → base64 (новый API)
                    do {
                        let payload = SdpPayload(
                            sdp: sdp,
                            type: "offer",
                            id: currentConnectionId ?? UUID().uuidString,
                            ts: Int64(Date().timeIntervalSince1970)
                        )
                        let bundle = ConnectionBundle(sdp_payload: payload, ice_candidates: collectedIceCandidates)
                        let serialized = try SdpSerializer.serializeBundle(bundle)
                        print("[\(timeString)] [WebRTC] Serialized offer bundle - id:", payload.id, "ts:", payload.ts)
                        print("[\(timeString)] [WebRTC] Serialized offer length:", serialized.count)
                        print("[\(timeString)] [WebRTC] ICE candidates in bundle:", collectedIceCandidates.count)
                        offerCompletion(serialized)
                        
                        // Очищаем состояние после отправки
                        collectedIceCandidates.removeAll()
                        currentConnectionId = nil
                    } catch {
                        print("[\(timeString)] [WebRTC] ERROR serializing offer:", error)
                        offerCompletion(nil)
                    }
                } else {
                    print("[\(timeString)] [WebRTC] ERROR: No local description for offer")
                    offerCompletion(nil)
                }
                self.offerCompletion = nil
            }
            
            // Для answer
            if let answerCompletion, peerConnection.localDescription?.type == .answer {
                let sdp = peerConnection.localDescription?.sdp
                if let sdp = sdp {
                    // Сериализуем ConnectionBundle через JSON → gzip → base64 (новый API)
                    do {
                        let payload = SdpPayload(
                            sdp: sdp,
                            type: "answer",
                            id: currentConnectionId ?? UUID().uuidString,
                            ts: Int64(Date().timeIntervalSince1970)
                        )
                        let bundle = ConnectionBundle(sdp_payload: payload, ice_candidates: collectedIceCandidates)
                        let serialized = try SdpSerializer.serializeBundle(bundle)
                        print("[\(timeString)] [WebRTC] Serialized answer bundle - id:", payload.id, "ts:", payload.ts)
                        print("[\(timeString)] [WebRTC] Serialized answer length:", serialized.count)
                        print("[\(timeString)] [WebRTC] ICE candidates in bundle:", collectedIceCandidates.count)
                        answerCompletion(serialized)
                        
                        // Очищаем состояние после отправки
                        collectedIceCandidates.removeAll()
                        currentConnectionId = nil
                    } catch {
                        print("[\(timeString)] [WebRTC] ERROR serializing answer:", error)
                        answerCompletion(nil)
                    }
                } else {
                    print("[\(timeString)] [WebRTC] ERROR: No local description for answer")
                    answerCompletion(nil)
                }
                self.answerCompletion = nil
            }
        }
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Signaling state changed:", stateChanged.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Stream added")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Stream removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] ICE connection state changed:", newState.rawValue)
        DispatchQueue.main.async {
            self.iceConnectionState = "\(newState.rawValue)"
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] ICE gathering state changed:", newState.rawValue)
        DispatchQueue.main.async {
            self.iceGatheringState = "\(newState.rawValue)"
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] ICE candidate added:", candidate.sdp)
        
        internalCandidateCount += 1
        DispatchQueue.main.async {
            self.candidateCount = "\(self.internalCandidateCount)"
        }
        
        // Проверяем, есть ли relay кандидат (TURN)
        if candidate.sdp.contains("relay") {
            hasRelayCandidate = true
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] Relay candidate found!")
        }
        
        // Добавляем кандидата в массив для ConnectionBundle
        if let connectionId = currentConnectionId {
            let iceCandidate = IceCandidate(
                candidate: candidate.sdp,
                sdp_mid: candidate.sdpMid,
                sdp_mline_index: Int(candidate.sdpMLineIndex),
                connection_id: connectionId
            )
            collectedIceCandidates.append(iceCandidate)
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] Added ICE candidate to collection, total:", collectedIceCandidates.count)
        }
        
        // Проверяем готовность для отдачи SDP
        checkIfReadyToReturnSDP(peerConnection)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] ICE candidates removed:", candidates.count)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] DataChannel opened (receiver)")
        
        // Устанавливаем dataChannel для receiver стороны
        self.dataChannel = dataChannel
        dataChannel.delegate = self
        
        // Генерируем ключевую пару если еще не сгенерирована
        if myPrivateKey == nil {
            let (privateKey, pubKeyBase64) = generateX25519KeyPair()
            myPrivateKey = privateKey
            myPubKey = pubKeyBase64
            print("[\(timeString)] [WebRTC] Generated X25519 keypair for receiver")
            
            // Проверяем, есть ли буферизованный ключ от peer
            if let bufferedPeerKey = pendingPeerPubKey {
                print("[\(timeString)] [WebRTC] Processing buffered peer pubkey for receiver")
                handleReceivedPubKey(bufferedPeerKey)
            }
        }
        
        // Отправляем pubkey при открытии data channel (для receiver)
        sendPubKey()
        
        DispatchQueue.main.async {
            self.dataChannelState = "открыт (receiver): \(dataChannel.readyState.rawValue)"
            self.isConnected = true
        }
    }
}

// MARK: - RTCDataChannelDelegate
extension WebRTCManager: RTCDataChannelDelegate {
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Received message, length:", buffer.data.count)
        
        if let message = String(data: buffer.data, encoding: .utf8) {
            print("[\(timeString)] [WebRTC] Received text message:", message)
            
            // Проверяем, является ли это pubkey сообщением
            if message.hasPrefix("PUBKEY:") {
                let pubKey = String(message.dropFirst(7)) // Убираем "PUBKEY:" префикс
                print("[\(timeString)] [WebRTC] Processing PUBKEY message, extracted key:", pubKey)
                handleReceivedPubKey(pubKey)
            } else {
                // Обычное сообщение чата (только если сверка завершена)
                if fingerprintVerificationState == .verified {
                    DispatchQueue.main.async {
                        self.receivedMessage = message
                    }
                } else {
                    let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                    print("[\(timeString2)] [WebRTC] Ignoring chat message - fingerprint not verified")
                }
            }
        } else {
            // Обработка зашифрованных бинарных сообщений
            print("[\(timeString)] [WebRTC] Received binary message, length:", buffer.data.count)
            
            guard fingerprintVerificationState == .verified else {
                let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString2)] [WebRTC] Ignoring encrypted message - SAS not verified")
                return
            }
            
            guard var context = cryptoContext else {
                let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString2)] [WebRTC] ERROR: No crypto context for decryption")
                return
            }
            
            do {
                // Расшифровка ChaCha20-Poly1305: входные данные = ciphertext || tag (без nonce)
                guard buffer.data.count >= tagLen else { return }
                let ct = buffer.data.dropLast(tagLen)
                let tag = buffer.data.suffix(tagLen)
                let nonceData = context.recvNonce.toChaChaNonceData()
                let sealedBox = try ChaChaPoly.SealedBox(nonce: ChaChaPoly.Nonce(data: nonceData), ciphertext: ct, tag: tag)
                let decryptedData = try ChaChaPoly.open(sealedBox, using: context.openingKey)
                
                if let decryptedText = String(data: decryptedData, encoding: .utf8) {
                    // Проверяем sequence number для защиты от replay атак
                    if context.recvNonce > context.lastAcceptedRecv {
                        context.lastAcceptedRecv = context.recvNonce
                        context.recvNonce += 1
                        self.cryptoContext = context
                        
                        let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                        print("[\(timeString2)] [WebRTC] Decrypted message:", decryptedText)
                        
                        DispatchQueue.main.async {
                            self.receivedMessage = decryptedText
                        }
                    } else {
                        let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                        print("[\(timeString2)] [WebRTC] Replay attack detected - ignoring message")
                    }
                } else {
                    let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                    print("[\(timeString2)] [WebRTC] ERROR: Failed to decode decrypted message as UTF-8")
                }
            } catch {
                let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print("[\(timeString2)] [WebRTC] ERROR decrypting message:", error)
            }
        }
    }
    
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] DataChannel state changed:", dataChannel.readyState.rawValue)
        
        DispatchQueue.main.async {
            self.dataChannelState = "\(dataChannel.readyState.rawValue)"
            
            switch dataChannel.readyState {
            case .open:
                self.isConnected = true
                print("[\(timeString)] [WebRTC] DataChannel opened - sending pubkey")
                // Отправляем pubkey при открытии data channel
                self.sendPubKey()
                
            case .closed:
                self.isConnected = false
                print("[\(timeString)] [WebRTC] DataChannel closed - resetting verification state")
                // Сбрасываем состояние сверки и криптографический контекст при закрытии
                self.fingerprintVerificationState = .notStarted
                self.isChatEnabled = false
                self.cryptoContext = nil
                self.myPrivateKey = nil
                self.pendingPeerPubKey = nil
                
            case .connecting:
                print("[\(timeString)] [WebRTC] DataChannel connecting...")
                // Генерируем ключевую пару заранее, чтобы быть готовыми к входящим сообщениям
                if self.myPrivateKey == nil {
                    let (privateKey, pubKeyBase64) = self.generateX25519KeyPair()
                    self.myPrivateKey = privateKey
                    self.myPubKey = pubKeyBase64
                    print("[\(timeString)] [WebRTC] Pre-generated X25519 keypair for incoming messages")
                    
                    // Проверяем, есть ли буферизованный ключ от peer
                    if let bufferedPeerKey = self.pendingPeerPubKey {
                        print("[\(timeString)] [WebRTC] Processing buffered peer pubkey")
                        self.handleReceivedPubKey(bufferedPeerKey)
                    }
                }
                
            case .closing:
                print("[\(timeString)] [WebRTC] DataChannel closing...")
                
            @unknown default:
                print("[\(timeString)] [WebRTC] DataChannel unknown state:", dataChannel.readyState.rawValue)
            }
        }
    }
} 
