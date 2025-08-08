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
        
        // Создаем тестовый payload с новой структурой
        let payload = SdpPayload(sdp: testSdp, type: "offer")
        print("Исходный SDP длина:", testSdp.count)
        print("Payload ID:", payload.id)
        print("Payload TS:", payload.ts)
        print("Payload SDP type:", payload.sdp.type)
        
        // Тестируем сериализацию
        do {
            let serialized = try SdpSerializer.serializeSdp(payload)
            print("Сериализованная строка длина:", serialized.count)
            
            // Тестируем десериализацию
            let deserialized = try SdpSerializer.deserializeSdp(serialized)
            print("Десериализованный payload ID:", deserialized.id)
            print("Десериализованный payload SDP type:", deserialized.sdp.type)
            print("Десериализованный SDP длина:", deserialized.sdp.sdp.count)
            
            // Проверяем совпадение
            if payload.id == deserialized.id && 
               payload.sdp.sdp == deserialized.sdp.sdp && 
               payload.sdp.type == deserialized.sdp.type {
                print("✅ Тест сериализации прошел успешно!")
            } else {
                print("❌ Тест сериализации провален!")
            }
        } catch {
            print("❌ Ошибка сериализации:", error)
        }
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
                candidate: "candidate:1 1 UDP 2122252543 192.168.1.1 12345 typ host",
                sdp_mid: "0",
                sdp_mline_index: 0,
                connection_id: "test-connection-id"
            ),
            IceCandidate(
                candidate: "candidate:2 1 UDP 1686052607 1.2.3.4 54321 typ srflx",
                sdp_mid: "0",
                sdp_mline_index: 0,
                connection_id: "test-connection-id"
            )
        ]
        
        // Создаем ConnectionBundle
        let payload = SdpPayload(sdp: testSdp, type: "offer")
        let bundle = ConnectionBundle(sdp_payload: payload, ice_candidates: iceCandidates)
        
        print("Bundle SDP type:", bundle.sdp_payload.sdp.type)
        print("Bundle ICE candidates count:", bundle.ice_candidates.count)
        
        // Тестируем сериализацию
        do {
            let serialized = try SdpSerializer.serializeBundle(bundle)
            print("Сериализованный bundle длина:", serialized.count)
            
            // Тестируем десериализацию
            let deserialized = try SdpSerializer.deserializeBundle(serialized)
            print("Десериализованный bundle SDP type:", deserialized.sdp_payload.sdp.type)
            print("Десериализованный bundle ICE candidates count:", deserialized.ice_candidates.count)
            
            // Проверяем совпадение
            if bundle.sdp_payload.id == deserialized.sdp_payload.id &&
               bundle.sdp_payload.sdp.sdp == deserialized.sdp_payload.sdp.sdp &&
               bundle.sdp_payload.sdp.type == deserialized.sdp_payload.sdp.type &&
               bundle.ice_candidates.count == deserialized.ice_candidates.count {
                print("✅ Тест ConnectionBundle прошел успешно!")
            } else {
                print("❌ Тест ConnectionBundle провален!")
            }
        } catch {
            print("❌ Ошибка сериализации ConnectionBundle:", error)
        }
    }
    
    static func testAutoDetection() {
        print("=== Тестирование автоматического определения типа ===")
        
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
        
        // Тест 1: ConnectionBundle (новый API)
        let payload = SdpPayload(sdp: testSdp, type: "offer")
        let bundle = ConnectionBundle(sdp_payload: payload, ice_candidates: [])
        
        do {
            let serialized = try SdpSerializer.serializeBundle(bundle)
            let (detectedPayload, detectedCandidates) = try SdpSerializer.deserializeAuto(serialized)
            
            print("Автоопределение ConnectionBundle:")
            print("  SDP type:", detectedPayload.sdp.type)
            print("  ICE candidates count:", detectedCandidates.count)
            
            if detectedPayload.sdp.type == "offer" && detectedCandidates.count == 0 {
                print("✅ Автоопределение ConnectionBundle работает!")
            } else {
                print("❌ Автоопределение ConnectionBundle провалено!")
            }
        } catch {
            print("❌ Ошибка автоопределения ConnectionBundle:", error)
        }
        
        // Тест 2: Legacy SdpPayload
        let legacyPayload = SdpPayload(sdp: testSdp, type: "answer")
        
        do {
            let serialized = try SdpSerializer.serializeSdp(legacyPayload)
            let (detectedPayload, detectedCandidates) = try SdpSerializer.deserializeAuto(serialized)
            
            print("Автоопределение Legacy SdpPayload:")
            print("  SDP type:", detectedPayload.sdp.type)
            print("  ICE candidates count:", detectedCandidates.count)
            
            if detectedPayload.sdp.type == "answer" && detectedCandidates.count == 0 {
                print("✅ Автоопределение Legacy SdpPayload работает!")
            } else {
                print("❌ Автоопределение Legacy SdpPayload провалено!")
            }
        } catch {
            print("❌ Ошибка автоопределения Legacy SdpPayload:", error)
        }
    }
    
    static func testCompressionRatio() {
        print("=== Тестирование коэффициента сжатия ===")
        
        // Создаем большой тестовый SDP
        var largeSdp = "v=0\no=- 1234567890 2 IN IP4 127.0.0.1\ns=-\nt=0 0\n"
        for i in 1...100 {
            largeSdp += "a=test-attribute-\(i):value-\(i)\n"
        }
        
        let payload = SdpPayload(sdp: largeSdp, type: "offer")
        let bundle = ConnectionBundle(sdp_payload: payload, ice_candidates: [])
        
        do {
            let json = try SdpSerializer.encodeConnectionBundle(bundle)
            let compressed = try SdpSerializer.gzipCompress(json)
            
            let originalSize = json.count
            let compressedSize = compressed.count
            let ratio = Double(compressedSize) / Double(originalSize) * 100
            
            print("Исходный размер JSON:", originalSize, "байт")
            print("Размер после GZIP:", compressedSize, "байт")
            print("Коэффициент сжатия:", String(format: "%.1f", ratio), "%")
            
            if ratio < 100 {
                print("✅ GZIP сжатие работает!")
            } else {
                print("❌ GZIP сжатие не работает!")
            }
        } catch {
            print("❌ Ошибка тестирования сжатия:", error)
        }
    }
} 