import SwiftUI

struct CopyField: View {
    let label: String
    let value: String
    var icon: String = "doc.on.doc"
    var onCopy: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            
            TextField("", text: .constant(value))
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(true)
        }
    }
}

