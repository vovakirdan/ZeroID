import SwiftUI

struct FutureTransferButton: View {
    let icon: String
    let title: String
    let isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isEnabled ? .accentColor : Color.textSecondary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(isEnabled ? Color.textPrimary : Color.textSecondary)
        }
        .frame(width: 60, height: 50)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.surfaceMuted)
                .opacity(isEnabled ? 1.0 : 0.5)
        )
        .disabled(!isEnabled)
    }
}

#Preview {
    HStack(spacing: 16) {
        FutureTransferButton(
            icon: "qrcode",
            title: "QR-код",
            isEnabled: false
        )
        
        FutureTransferButton(
            icon: "wave.3.right",
            title: "Bluetooth",
            isEnabled: true
        )
    }
    .padding()
} 