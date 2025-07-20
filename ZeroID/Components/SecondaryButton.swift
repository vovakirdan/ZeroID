import SwiftUI

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.regular)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary)
                .foregroundColor(.accentColor)
                .cornerRadius(14)
        }
    }
}

