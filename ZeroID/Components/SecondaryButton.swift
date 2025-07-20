import SwiftUI

struct SecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .fontWeight(.regular)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.surfaceSecondary)
            .foregroundColor(Color.textPrimary)
            .cornerRadius(14)
        }
    }
}

