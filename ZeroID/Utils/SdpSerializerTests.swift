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