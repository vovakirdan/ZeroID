import SwiftUI

struct PrimaryButton: View {
    let title: String
    let arrow: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .fontWeight(.semibold)
                if arrow {
                    Image(systemName: "arrow.right")
                        .font(.body)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.primaryGradient)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
    }
}

