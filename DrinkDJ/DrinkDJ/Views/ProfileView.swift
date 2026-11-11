import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var username = MockData.profileName
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var repeatedPassword = ""

    @State private var showDeleteConfirmation = false
    @State private var activeAlert: ProfileAlert?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                backButton
                profileHeader
                settingsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Delete account?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                activeAlert = .deleteUnavailable
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action would permanently delete your account.")
        }
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var backButton: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)

            Spacer()
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROFILE")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(.pink)

                    Text(username.isEmpty ? MockData.profileName : username)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 0)

                Image(MockData.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 82, height: 82)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.35), lineWidth: 1)
                    }
            }

            HStack {
                Spacer()

                Text("Since \(MockData.profileJoinedDate)")
                    .font(.caption.weight(.medium))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }

    private var settingsCard: some View {
        VStack(spacing: 20) {
            NavigationLink {
                PreferencesView()
            } label: {
                VStack(spacing: 8) {
                    Text("CONSOLE")
                        .font(.subheadline.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(.cyan)

                    Text("SET YOUR PREFERENCES")
                        .font(.caption.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .controlSize(.large)
            .glassButtonStyle()

            Divider()
                .overlay(.white.opacity(0.35))

            usernameSection

            emailSection

            Divider()
                .overlay(.white.opacity(0.35))

            passwordSection

            Divider()
                .overlay(.white.opacity(0.35))

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Text("DELETE ACCOUNT")
                    .font(.caption.weight(.bold))
                    .tracking(2)
            }
            .tint(.pink)
            .controlSize(.large)
            .glassButtonStyle()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        }
    }

    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("USERNAME")

            TextField("Username", text: $username)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(.black.opacity(0.65), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                }
                .foregroundStyle(.white)

            centeredGlassButton("CHANGE USERNAME") {
                let trimmedName = username.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmedName.isEmpty else {
                    activeAlert = .emptyUsername
                    return
                }

                username = trimmedName
                activeAlert = .usernameNotSaved
            }
        }
    }

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("EMAIL")

            Text(MockData.email)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .background(.black.opacity(0.65), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                }
        }
    }

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("PASSWORD")

            SecureField("Current Password", text: $currentPassword)
                .profilePasswordFieldStyle()

            SecureField("New Password", text: $newPassword)
                .profilePasswordFieldStyle()

            SecureField("New Password Repeat", text: $repeatedPassword)
                .profilePasswordFieldStyle()

            centeredGlassButton("CHANGE PASSWORD") {
                guard !currentPassword.isEmpty else {
                    activeAlert = .emptyCurrentPassword
                    return
                }

                guard currentPassword == MockData.password else {
                    activeAlert = .incorrectCurrentPassword
                    return
                }

                guard !newPassword.isEmpty else {
                    activeAlert = .emptyNewPassword
                    return
                }

                guard newPassword == repeatedPassword else {
                    activeAlert = .passwordsDoNotMatch
                    return
                }

                activeAlert = .passwordChangeUnavailable
                currentPassword = ""
                newPassword = ""
                repeatedPassword = ""
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .tracking(2)
            .foregroundStyle(.pink)
    }

    private func centeredGlassButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Spacer()

            Button(action: action) {
                Text(title)
                    .frame(minWidth: 180)
            }
            .controlSize(.large)
            .glassButtonStyle()

            Spacer()
        }
    }
}

private extension View {
    func profilePasswordFieldStyle() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(.black.opacity(0.65), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.45), lineWidth: 1)
            }
            .foregroundStyle(.white)
    }
}

private enum ProfileAlert: String, Identifiable {
    case deleteUnavailable
    case emptyUsername
    case usernameNotSaved
    case emptyCurrentPassword
    case incorrectCurrentPassword
    case emptyNewPassword
    case passwordsDoNotMatch
    case passwordChangeUnavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deleteUnavailable:
            return "Account deletion isn’t connected"
        case .emptyUsername:
            return "Enter a username"
        case .usernameNotSaved:
            return "Mock profile"
        case .emptyCurrentPassword:
            return "Enter your current password"
        case .incorrectCurrentPassword:
            return "Incorrect current password"
        case .emptyNewPassword:
            return "Enter a new password"
        case .passwordsDoNotMatch:
            return "Passwords don’t match"
        case .passwordChangeUnavailable:
            return "Password change isn’t connected"
        }
    }

    var message: String {
        switch self {
        case .deleteUnavailable:
            return "The confirmation works, but this prototype has no account deletion service yet."
        case .emptyUsername:
            return "The username can’t be empty."
        case .usernameNotSaved:
            return "The username changed on this screen, but isn’t saved between launches."
        case .emptyCurrentPassword:
            return "Enter the password you use to log in."
        case .incorrectCurrentPassword:
            return "The current password doesn’t match the mock account."
        case .emptyNewPassword:
            return "Enter a new password first."
        case .passwordsDoNotMatch:
            return "Make sure both new password fields match."
        case .passwordChangeUnavailable:
            return "The current password was verified, but this prototype can’t save a changed password yet."
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
