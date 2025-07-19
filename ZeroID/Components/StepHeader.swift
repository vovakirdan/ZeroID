import SwiftUI

struct StepHeader: View {
    let title: String
    let subtitle: String
    let icon: String?
    
    var body: some View {
        VStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
            }
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 18)
    }
}
