import SwiftUI

struct AccountButton: View {
    var body: some View {
        NavigationLink {
            ProfileView()
        } label: {
            Image(MockData.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .frame(width: 48, height: 48, alignment: .topTrailing)
        .accessibilityLabel("Open profile")
    }
}

#Preview {
    NavigationStack {
        AccountButton()
            .preferredColorScheme(.dark)
    }
}
