import Foundation

// Тестовые функции для проверки пайплайна сериализации
struct SdpSerializerTests {
    
    static func testSerializationPipeline() {
        print("=== Тестирование пайплайна сериализации SDP ===")
        
        // Создаем тестовый SDP
        let testSdp = """
        v=0
        o=- 1234567890 2 IN IP4 127.0.0.1
        s=-
        t=0 0
        a=group:BUNDLE 0
        m=application 9 UDP/DTLS/SCTP webrtc-datachannel
        c=IN IP4 0.0.0.0
        a=mid:0
        a=sctp-port:5000
        """
        
        // Создаем тестовый payload
        let payload = SdpPayload(sdp: testSdp)
        print("Исходный SDP длина:", testSdp.count)
        print("Payload ID:", payload.id)
        print("Payload TS:", payload.ts)
        
        // Тестируем сериализацию
        do {
            let serialized = try SdpSerializer.serializeSdp(payload)
            print("Сериализованная строка длина:", serialized.count)
            print("Сериализованная строка (первые 100 символов):", String(serialized.prefix(100)))
            
            // Тестируем десериализацию
            let deserialized = try SdpSerializer.deserializeSdp(serialized)
            print("Десериализованный SDP длина:", deserialized.sdp.count)
            print("Десериализованный ID:", deserialized.id)
            print("Десериализованный TS:", deserialized.ts)
            
            // Проверяем совпадение
            let sdpMatch = payload.sdp == deserialized.sdp
            let idMatch = payload.id == deserialized.id
            let tsMatch = payload.ts == deserialized.ts
            
            print("SDP совпадает:", sdpMatch)
            print("ID совпадает:", idMatch)
            print("TS совпадает:", tsMatch)
            
            if sdpMatch && idMatch && tsMatch {
                print("✅ Пайплайн работает корректно!")
            } else {
                print("❌ Ошибка в пайплайне!")
            }
            
        } catch {
            print("❌ Ошибка тестирования:", error)
        }
        
        print("=== Конец тестирования ===\n")
    }
    
    static func testConnectionBundlePipeline() {
        print("=== Тестирование пайплайна ConnectionBundle ===")
        
        // Создаем тестовый SDP
        let testSdp = """
        v=0
        o=- 1234567890 2 IN IP4 127.0.0.1
        s=-
        t=0 0
        a=group:BUNDLE 0
        m=application 9 UDP/DTLS/SCTP webrtc-datachannel
        c=IN IP4 0.0.0.0
        a=mid:0
        a=sctp-port:5000
        """
        
        // Создаем тестовые ICE кандидаты
        let iceCandidates = [
            IceCandidate(
                candidate: "candidate:1 1 udp 2122252543 192.168.1.100 5000 typ host",
                sdp_mid: "0",
                sdp_mline_index: 0,
                connection_id: "conn1"
            ),
            IceCandidate(
                candidate: "candidate:2 1 udp 1686052607 203.0.113.1 5000 typ srflx",
                sdp_mid: "0",
                sdp_mline_index: 0,
                connection_id: "conn2"
            )
        ]
        
        // Создаем ConnectionBundle
        let sdpPayload = SdpPayload(sdp: testSdp)
        let bundle = ConnectionBundle(sdp_payload: sdpPayload, ice_candidates: iceCandidates)
        
        print("SDP Payload ID:", bundle.sdp_payload.id)
        print("ICE кандидатов:", bundle.ice_candidates.count)
        
        // Тестируем сериализацию ConnectionBundle
        do {
            let serialized = try SdpSerializer.serializeBundle(bundle)
            print("Сериализованная строка длина:", serialized.count)
            print("Сериализованная строка (первые 100 символов):", String(serialized.prefix(100)))
            
            // Тестируем десериализацию
            let deserialized = try SdpSerializer.deserializeBundle(serialized)
            print("Десериализованный SDP длина:", deserialized.sdp_payload.sdp.count)
            print("Десериализованный ID:", deserialized.sdp_payload.id)
            print("Десериализованных кандидатов:", deserialized.ice_candidates.count)
            
            // Проверяем совпадение
            let sdpMatch = bundle.sdp_payload.sdp == deserialized.sdp_payload.sdp
            let idMatch = bundle.sdp_payload.id == deserialized.sdp_payload.id
            let candidatesMatch = bundle.ice_candidates.count == deserialized.ice_candidates.count
            
            print("SDP совпадает:", sdpMatch)
            print("ID совпадает:", idMatch)
            print("Кандидаты совпадают:", candidatesMatch)
            
            if sdpMatch && idMatch && candidatesMatch {
                print("✅ ConnectionBundle пайплайн работает корректно!")
            } else {
                print("❌ Ошибка в ConnectionBundle пайплайне!")
            }
            
        } catch {
            print("❌ Ошибка тестирования ConnectionBundle:", error)
        }
        
        print("=== Конец тестирования ConnectionBundle ===\n")
    }
    
    static func testAutoDetection() {
        print("=== Тестирование автоматического определения типа ===")
        
        // Тест 1: Legacy SdpPayload
        let legacySdp = """
        v=0
        o=- 1234567890 2 IN IP4 127.0.0.1
        s=-
        t=0 0
        """
        
        let legacyPayload = SdpPayload(sdp: legacySdp)
        
        do {
            let serialized = try SdpSerializer.serializeSdp(legacyPayload)
            let (detectedPayload, detectedCandidates) = try SdpSerializer.deserializeAuto(serialized)
            
            print("Legacy API - SDP совпадает:", legacyPayload.sdp == detectedPayload.sdp)
            print("Legacy API - Кандидатов:", detectedCandidates.count)
            
        } catch {
            print("❌ Ошибка тестирования Legacy API:", error)
        }
        
        // Тест 2: Новый ConnectionBundle
        let newSdp = """
        v=0
        o=- 9876543210 2 IN IP4 127.0.0.1
        s=-
        t=0 0
        """
        
        let iceCandidates = [
            IceCandidate(
                candidate: "candidate:1 1 udp 2122252543 192.168.1.100 5000 typ host",
                sdp_mid: "0",
                sdp_mline_index: 0,
                connection_id: "conn1"
            )
        ]
        
        let newPayload = SdpPayload(sdp: newSdp)
        let bundle = ConnectionBundle(sdp_payload: newPayload, ice_candidates: iceCandidates)
        
        do {
            let serialized = try SdpSerializer.serializeBundle(bundle)
            let (detectedPayload, detectedCandidates) = try SdpSerializer.deserializeAuto(serialized)
            
            print("Новый API - SDP совпадает:", newPayload.sdp == detectedPayload.sdp)
            print("Новый API - Кандидатов:", detectedCandidates.count)
            
        } catch {
            print("❌ Ошибка тестирования нового API:", error)
        }
        
        print("=== Конец тестирования автоматического определения ===\n")
    }
    
    static func testCompressionRatio() {
        print("=== Тестирование сжатия ===")
        
        // Создаем большой тестовый SDP
        var largeSdp = "v=0\no=- 1234567890 2 IN IP4 127.0.0.1\ns=-\nt=0 0\n"
        
        // Добавляем много кандидатов для тестирования сжатия
        for i in 0..<100 {
            largeSdp += "a=candidate:\(i) 1 udp 2122252543 192.168.1.\(i) 5000 typ host\n"
        }
        
        let payload = SdpPayload(sdp: largeSdp)
        print("Исходный SDP размер:", largeSdp.count, "байт")
        
        do {
            let serialized = try SdpSerializer.serializeSdp(payload)
            print("Сжатый размер:", serialized.count, "байт")
            
            let compressionRatio = Double(serialized.count) / Double(largeSdp.count) * 100
            print("Коэффициент сжатия: \(String(format: "%.1f", compressionRatio))%")
            
        } catch {
            print("❌ Ошибка тестирования сжатия:", error)
        }
        
        print("=== Конец тестирования сжатия ===\n")
    }
} 