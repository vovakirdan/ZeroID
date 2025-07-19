// WebRTCManager.swift

import Foundation
import WebRTC

class WebRTCManager: NSObject, ObservableObject {
    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var factory: RTCPeerConnectionFactory
    private let iceServers = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun2.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun3.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun4.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["turn:relay1.expressturn.com:3480"],  // это временные, их можно на публику
                     username: "000000002067703673",
                     credential: "aUS5WkBI4dk568G6L/uv7ZQvBAQ=")
    ]

    @Published var receivedMessage: String = ""
    @Published var isConnected: Bool = false
    @Published var dataChannelState: String = "не создан"
    @Published var iceConnectionState: String = "не создан"

    override init() {
        print("[WebRTCManager] Init")
        RTCInitializeSSL()
        self.factory = RTCPeerConnectionFactory()
        super.init()
    }

    // Создание peerConnection
    func createPeerConnection() -> RTCPeerConnection {
        print("[WebRTC] Creating peerConnection")
        let config = RTCConfiguration()
        config.iceServers = iceServers
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

    // Создать оффер (инициатор)
    func createOffer(completion: @escaping (String?) -> Void) {
        // Добавляем время к каждому print
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Initiator: creating offer")
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
                completion(sdp.sdp)
            })
        }
    }

    // Принять remote offer, создать answer
    func receiveOffer(_ offerSDP: String, completion: @escaping (String?) -> Void) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Receiver: received offer, setting remote desc")
        
        // Валидация SDP - только базовый trim по краям
        let cleanedSDP = offerSDP // .trimmingCharacters(in: .whitespacesAndNewlines)
        print("[\(timeString)] [WebRTC] Offer SDP length:", cleanedSDP.count)
        
        if cleanedSDP.isEmpty {
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] ERROR: Offer SDP is empty")
            completion(nil)
            return
        }
        
        // Проверяем, что SDP начинается с правильного формата
        if !cleanedSDP.hasPrefix("v=0") {
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] ERROR: Offer SDP has invalid format (should start with 'v=0')")
            print("[\(timeString2)] [WebRTC] SDP starts with:", String(cleanedSDP.prefix(10)))
            completion(nil)
            return
        }
        
        // Детальное логирование SDP для диагностики
        let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString2)] [WebRTC] Offer SDP content (first 100 chars):", String(cleanedSDP.prefix(100)))
        
        self.peerConnection = createPeerConnection()
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let sdp = RTCSessionDescription(type: .offer, sdp: cleanedSDP)
        peerConnection?.setRemoteDescription(sdp, completionHandler: { [weak self] error in
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            if let error = error {
                print("[\(timeString2)] [WebRTC] ERROR setting remote description:", error)
                completion(nil)
                return
            }
            print("[\(timeString2)] [WebRTC] Remote description set successfully")
            self?.peerConnection?.answer(for: constraints, completionHandler: { answerSdp, err in
                let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                if let err = err {
                    print("[\(timeString3)] [WebRTC] ERROR creating answer:", err)
                    completion(nil)
                    return
                }
                guard let answerSdp = answerSdp else { 
                    print("[\(timeString3)] [WebRTC] ERROR: Answer SDP is nil")
                    completion(nil)
                    return 
                }
                print("[\(timeString3)] [WebRTC] Answer created successfully")
                self?.peerConnection?.setLocalDescription(answerSdp, completionHandler: { err2 in
                    let timeString4 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                    if let err2 = err2 {
                        print("[\(timeString4)] [WebRTC] ERROR setting local answer description:", err2)
                    } else {
                        print("[\(timeString4)] [WebRTC] Local answer description set successfully")
                    }
                    completion(answerSdp.sdp)
                })
            })
        })
    }

    // Принять answer на стороне инициатора
    func receiveAnswer(_ answerSDP: String) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Initiator: received answer, setting remote desc")
        
        // Валидация SDP - только базовый trim по краям
        let cleanedSDP = answerSDP // .trimmingCharacters(in: .whitespacesAndNewlines)
        print("[\(timeString)] [WebRTC] Answer SDP length:", cleanedSDP.count)
        
        if cleanedSDP.isEmpty {
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] ERROR: Answer SDP is empty")
            return
        }
        
        // Проверяем, что SDP начинается с правильного формата
        if !cleanedSDP.hasPrefix("v=0") {
            let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString3)] [WebRTC] ERROR: Answer SDP has invalid format (should start with 'v=0')")
            print("[\(timeString3)] [WebRTC] SDP starts with:", String(cleanedSDP.prefix(10)))
            return
        }
        
        // Детальное логирование SDP для диагностики
        let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString2)] [WebRTC] Answer SDP content (first 100 chars):", String(cleanedSDP.prefix(100)))
        
        guard let pc = self.peerConnection else { 
            let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString3)] [WebRTC] ERROR: No peer connection for answer")
            return 
        }
        
        let sdp = RTCSessionDescription(type: .answer, sdp: cleanedSDP)
        pc.setRemoteDescription(sdp, completionHandler: { err in
            let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            if let err = err {
                print("[\(timeString3)] [WebRTC] ERROR setting remote answer description:", err)
            } else {
                print("[\(timeString3)] [WebRTC] Remote answer description set successfully")
            }
        })
    }

    // Отправка сообщения через dataChannel
    func sendMessage(_ text: String) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Sending message:", text)
        guard let dc = dataChannel, dc.readyState == .open else { 
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] ERROR: DataChannel not ready, state:", dataChannel?.readyState.rawValue ?? -1)
            return 
        }
        let buffer = RTCDataBuffer(data: text.data(using: .utf8)!, isBinary: false)
        dc.sendData(buffer)
        let timeString3 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString3)] [WebRTC] Message sent successfully")
    }
}

extension WebRTCManager: RTCPeerConnectionDelegate {
    // Реализация только нужных методов (здесь пока пусто)
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Signaling state changed:", stateChanged.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Media stream added")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Media stream removed")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] Should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] ICE connection state:", newState.rawValue)
        DispatchQueue.main.async {
            self.iceConnectionState = "ICE: \(newState.rawValue)"
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] ICE gathering state:", newState.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] ICE candidate generated")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] ICE candidates removed")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] didOpen dataChannel:", dataChannel.label)
        self.dataChannel = dataChannel
        dataChannel.delegate = self
        DispatchQueue.main.async {
            self.isConnected = true
            self.dataChannelState = "открыт (получен): \(dataChannel.readyState.rawValue)"
        }
    }
}

extension WebRTCManager: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] DataChannel state:", dataChannel.readyState.rawValue)
        DispatchQueue.main.async {
            self.dataChannelState = "состояние: \(dataChannel.readyState.rawValue)"
        }
        if dataChannel.readyState == .open {
            DispatchQueue.main.async {
                self.isConnected = true
                self.dataChannelState = "открыт: \(dataChannel.readyState.rawValue)"
            }
        }
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        let timeString = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timeString)] [WebRTC] DataChannel received message:", buffer.data)
        if let text = String(data: buffer.data, encoding: .utf8) {
            let timeString2 = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timeString2)] [WebRTC] Received text:", text)
            DispatchQueue.main.async {
                self.receivedMessage = text
            }
        }
    }
}

