// WebRTCManager.swift

import Foundation
import WebRTC

class WebRTCManager: NSObject, ObservableObject {
    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var factory: RTCPeerConnectionFactory
    private let iceServers = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
    ]

    @Published var receivedMessage: String = ""

    override init() {
        RTCInitializeSSL()
        self.factory = RTCPeerConnectionFactory()
        super.init()
    }

    // Создание peerConnection
    func createPeerConnection() -> RTCPeerConnection {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            fatalError("Failed to create RTCPeerConnection")
        }
        self.peerConnection = pc
        return pc
    }

    // Создать оффер (инициатор)
    func createOffer(completion: @escaping (String?) -> Void) {
        self.peerConnection = createPeerConnection()
        let dataChannelConfig = RTCDataChannelConfiguration()
        let dc = peerConnection!.dataChannel(forLabel: "chat", configuration: dataChannelConfig)
        dc?.delegate = self
        self.dataChannel = dc

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let sdp = sdp else { completion(nil); return }
            self?.peerConnection?.setLocalDescription(sdp, completionHandler: { err in
                completion(sdp.sdp)
            })
        }
    }

    // Принять remote offer, создать answer
    func receiveOffer(_ offerSDP: String, completion: @escaping (String?) -> Void) {
        self.peerConnection = createPeerConnection()
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let sdp = RTCSessionDescription(type: .offer, sdp: offerSDP)
        peerConnection?.setRemoteDescription(sdp, completionHandler: { [weak self] error in
            self?.peerConnection?.answer(for: constraints, completionHandler: { answerSdp, err in
                guard let answerSdp = answerSdp else { completion(nil); return }
                self?.peerConnection?.setLocalDescription(answerSdp, completionHandler: { err2 in
                    completion(answerSdp.sdp)
                })
            })
        })
    }

    // Принять answer на стороне инициатора
    func receiveAnswer(_ answerSDP: String) {
        guard let pc = self.peerConnection else { return }
        let sdp = RTCSessionDescription(type: .answer, sdp: answerSDP)
        pc.setRemoteDescription(sdp, completionHandler: { err in
            // Соединение готово
        })
    }

    // Отправка сообщения через dataChannel
    func sendMessage(_ text: String) {
        guard let dc = dataChannel, dc.readyState == .open else { return }
        let buffer = RTCDataBuffer(data: text.data(using: .utf8)!, isBinary: false)
        dc.sendData(buffer)
    }
}

extension WebRTCManager: RTCPeerConnectionDelegate {
    // Реализация только нужных методов (здесь пока пусто)
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        self.dataChannel = dataChannel
        dataChannel.delegate = self
    }
}

extension WebRTCManager: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {}

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if let text = String(data: buffer.data, encoding: .utf8) {
            DispatchQueue.main.async {
                self.receivedMessage = text
            }
        }
    }
}

