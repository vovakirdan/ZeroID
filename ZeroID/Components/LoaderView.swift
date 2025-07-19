import SwiftUI

struct LoaderView: View {
    var text: String = "Ждём соединения..."
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

