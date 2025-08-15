import SwiftUI
import PhotosUI
import UIKit
import SWCompression

struct QuickShareSection: View {
    let step: HandshakeStep
    let sdpText: String
    @Binding var remoteSDP: String
    let onPaste: () -> Void

    @State private var showQR = false
    @State private var generatedQR: UIImage? = nil
    @State private var showScanner = false
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showInvalidAlert = false
    @State private var showShareOptions = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    var body: some View {
        VStack(spacing: 12) {
            Text("Быстрый обмен")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            
            HStack(spacing: 12) {
                // Показать QR
                SecondaryButton(title: "Показать QR", icon: "qrcode") {
                    generatedQR = QRUtils.generateQR(from: sdpText)
                    showQR = true
                }
                .disabled(sdpText.isEmpty)
                
                // Сканировать QR (камера)
                SecondaryButton(title: "Сканировать", icon: "qrcode.viewfinder") {
                    showScanner = true
                }
                
                // Поделиться (выбор Текст/QR)
                SecondaryButton(title: "Поделиться", icon: "square.and.arrow.up") {
                    showShareOptions = true
                }
                .disabled(sdpText.isEmpty)
            }
            
            HStack(spacing: 12) {
                // Загрузить QR из галереи
                PhotosPicker(selection: $photoItem, matching: .images) {
                    SecondaryButton(title: "QR из галереи", icon: "photo") {}
                }
                
                // Сохранить QR в фото
                SecondaryButton(title: "Сохранить QR", icon: "square.and.arrow.down") {
                    if let img = QRUtils.generateQR(from: sdpText) {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                    }
                }
                .disabled(sdpText.isEmpty)
            }
        }
        .sheet(isPresented: $showShareSheet) { ActivityView(activityItems: shareItems) }
        .sheet(isPresented: $showQR) {
            VStack { if let img = generatedQR { Image(uiImage: img).interpolation(.none).resizable().scaledToFit().padding() } }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView(onCode: { payload in
                // Проверяем полезность и заполняем поле
                if isLikelyValidPayload(payload) {
                    remoteSDP = payload
                    onPaste()
                } else {
                    showInvalidAlert = true
                }
                showScanner = false
            }, onClose: {
                showScanner = false
            })
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { oldValue, newItem in
            guard let newItem = newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    QRUtils.detectQRCode(in: ui) { payload in
                        DispatchQueue.main.async {
                            if let payload, isLikelyValidPayload(payload) {
                                remoteSDP = payload
                                onPaste()
                            } else {
                                showInvalidAlert = true
                            }
                        }
                    }
                }
                self.photoItem = nil
            }
        }
        .alert("Неверный QR-код", isPresented: $showInvalidAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("QR не содержит корректный оффер/ответ")
        }
        .confirmationDialog("Поделиться", isPresented: $showShareOptions, titleVisibility: .visible) {
            Button("Текст") {
                shareItems = [sdpText]
                showShareSheet = true
            }
            Button("QR-картинка") {
                if let img = QRUtils.generateQR(from: sdpText) {
                    shareItems = [img]
                } else {
                    shareItems = [sdpText]
                }
                showShareSheet = true
            }
            Button("Отмена", role: .cancel) {}
        }
    }

    // Простая эвристика валидности: поддержка новых префиксов c:/cb: и legacy base64+gzip
    private func isLikelyValidPayload(_ s: String) -> Bool {
        // Компактные форматы: c:/cb: — считаем валидными
        if s.hasPrefix("c:") || s.hasPrefix("cb:") { return true }
        if let data = Data(base64Encoded: s),
           let decompressed = try? SWCompression.GzipArchive.unarchive(archive: data),
           let json = try? JSONSerialization.jsonObject(with: decompressed) as? [String: Any] {
            // Новый API: ожидаем ключи sdp_payload/ice_candidates
            if json["sdp_payload"] != nil { return true }
            // Legacy: поле sdp
            if let sdpObj = json["sdp"] as? [String: Any], let sdp = sdpObj["sdp"] as? String {
                return sdp.hasPrefix("v=0")
            }
        }
        return false
    }
}


