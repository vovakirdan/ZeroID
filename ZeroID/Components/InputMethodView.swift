import SwiftUI
import PhotosUI
import SWCompression

struct InputMethodView: View {
    let label: String
    @Binding var inputText: String
    let onPaste: () -> Void
    
    @State private var showingTextInput = true
    @State private var showScanner = false
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showInvalidAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            if showingTextInput {
                HStack {
                    TextField("", text: $inputText)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        if inputText.isEmpty {
                            // Кнопка Paste
                            if let clipboard = UIPasteboard.general.string {
                                inputText = clipboard
                                onPaste()
                            }
                        } else {
                            // Кнопка Delete
                            inputText = ""
                        }
                    }) {
                        Image(systemName: inputText.isEmpty ? "doc.on.clipboard" : "trash")
                            .font(.title3)
                            .foregroundColor(inputText.isEmpty ? .accentColor : .destructive)
                    }
                }
            } else {
                // Режим без поля ввода — ждём скан/выбор фото
                VStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 40))
                        .foregroundColor(Color.textSecondary)
                    Text("Откройте камеру для сканирования или выберите фото с QR")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(Color.surfaceMuted)
                .cornerRadius(10)
            }
            // Переключатель способов ввода
            HStack(spacing: 8) {
                Spacer()
                
                InputMethodButton(
                    icon: "text.cursor",
                    title: "Текст",
                    isSelected: showingTextInput,
                    action: { showingTextInput = true }
                )
                
                InputMethodButton(
                    icon: "qrcode.viewfinder",
                    title: "Скан QR",
                    isSelected: !showingTextInput && showScanner,
                    action: {
                        showingTextInput = false
                        showScanner = true
                    }
                )
                
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    // Важно: label не должен быть обычной кнопкой с собственным action
                    HStack(spacing: 6) {
                        Image(systemName: "photo").font(.caption)
                        Text("Из фото").font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(!showingTextInput && photoItem != nil ? Color.accentColor : Color.surfaceSecondary)
                    .foregroundColor(!showingTextInput && photoItem != nil ? .white : Color.textPrimary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(!showingTextInput && photoItem != nil ? Color.accentColor : Color.borderPrimary, lineWidth: 1)
                    )
                }
                
                Spacer()
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView(onCode: { payload in
                    if isLikelyValidPayload(payload) {
                        inputText = payload
                        onPaste()
                        showingTextInput = true
                    } else {
                        showInvalidAlert = true
                    }
                    showScanner = false
                }, onClose: {
                    showScanner = false
                })
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { newItem in
                guard let newItem = newItem else { return }
                Task {
                    showingTextInput = false
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        QRUtils.detectQRCode(in: ui) { payload in
                            DispatchQueue.main.async {
                                if let payload, isLikelyValidPayload(payload) {
                                    inputText = payload
                                    onPaste()
                                    showingTextInput = true
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
        }
    }
}

struct InputMethodButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.surfaceSecondary)
            .foregroundColor(isSelected ? .white : (isEnabled ? Color.textPrimary : Color.textSecondary))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.borderPrimary, lineWidth: 1)
            )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// Простейшая эвристика валидности полезной нагрузки из QR
private func isLikelyValidPayload(_ s: String) -> Bool {
    if let data = Data(base64Encoded: s),
       let decompressed = try? SWCompression.GzipArchive.unarchive(archive: data),
       let json = try? JSONSerialization.jsonObject(with: decompressed) as? [String: Any] {
        if json["sdp_payload"] != nil { return true }
        if let sdpObj = json["sdp"] as? [String: Any], let sdp = sdpObj["sdp"] as? String {
            return sdp.hasPrefix("v=0")
        }
    }
    return false
}

#Preview {
    InputMethodViewPreview()
}

private struct InputMethodViewPreview: View {
    @State var text = "ррр"
    var body: some View {
        VStack {
            InputMethodView(
                label: "Вставь Offer от peer-а:",
                inputText: $text,
                onPaste: {}
            )
            .padding()
            
            Spacer()
        }
        .background(Color.background)
    }
}
