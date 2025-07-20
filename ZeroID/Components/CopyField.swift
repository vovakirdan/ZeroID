import SwiftUI

struct CopyField: View {
    let label: String
    let value: String
    var icon: String = "doc.on.doc"
    var onCopy: (() -> Void)?
    
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            
            HStack(alignment: .center) {
                TextEditor(text: .constant(value))
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 110)
                    .cornerRadius(10)
                    .disabled(true)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.borderPrimary, lineWidth: 1))
                Button(action: {
                    UIPasteboard.general.string = value
                    copied = true
                    onCopy?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }) {
                    Image(systemName: copied ? "checkmark.circle.fill" : icon)
                        .font(.title2)
                        .foregroundColor(copied ? .green : .accentColor)
                        .scaleEffect(copied ? 1.2 : 1)
                        .animation(.spring(response: 0.3), value: copied)
                }
                .padding(.trailing, 6)
            }
        }
    }
}

