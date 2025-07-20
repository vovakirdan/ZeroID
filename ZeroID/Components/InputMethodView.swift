import SwiftUI

struct InputMethodView: View {
    let label: String
    @Binding var inputText: String
    let onPaste: () -> Void
    
    @State private var showingTextInput = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            
            // Переключатель способов ввода
            HStack(spacing: 8) {
                InputMethodButton(
                    icon: "text.cursor",
                    title: "Текст",
                    isSelected: showingTextInput,
                    action: { showingTextInput = true }
                )
                
                InputMethodButton(
                    icon: "qrcode.viewfinder",
                    title: "Скан QR",
                    isSelected: false,
                    isEnabled: false,
                    action: { /* TODO: Реализовать скан QR */ }
                )
                
                InputMethodButton(
                    icon: "photo",
                    title: "Из фото",
                    isSelected: false,
                    isEnabled: false,
                    action: { /* TODO: Реализовать загрузку из фото */ }
                )
                
                Spacer()
            }
            
            
            
            if showingTextInput {
                VStack(spacing: 8) {
                    HStack {
                        TextEditor(text: $inputText)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 100)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderPrimary, lineWidth: 1))
                        
                        VStack(spacing: 8) {
                            Button(action: {
                                if let clipboard = UIPasteboard.general.string {
                                    inputText = clipboard
                                    onPaste()
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                            }
                            
                            Button(action: {
                                inputText = ""
                            }) {
                                Image(systemName: "trash")
                                    .font(.title3)
                                    .foregroundColor(.destructive)
                            }
                        }
                        .padding(.trailing, 4)
                    }
                }
            } else {
                // Заглушка для будущих методов ввода
                VStack(spacing: 16) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color.textSecondary)
                    
                    Text("Скоро будет доступно")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .background(Color.surfaceMuted)
                .cornerRadius(10)
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

#Preview {
    @Previewable @State var text = ""
    
    return VStack {
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
