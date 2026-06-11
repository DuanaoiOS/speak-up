import SwiftUI

struct ErrorMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
