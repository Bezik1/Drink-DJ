import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var username = MockData.profileName
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var repeatedPassword = ""
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var profilePhotoData: Data?

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
        .onChange(of: selectedProfilePhoto) { item in
            guard let item else { return }
            Task { @MainActor in
                profilePhotoData = try? await item.loadTransferable(type: Data.self)
            }
        }
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
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background {
                        if #available(iOS 26, *) {
                            Circle().fill(.clear)
                                .glassEffect(.regular, in: .circle)
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                    .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))
            }
            .accessibilityLabel("Back")

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

                PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                    profilePhoto
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                                .offset(x: 2, y: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change profile photo")
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

    @ViewBuilder
    private var profilePhoto: some View {
        if let profilePhotoData, let image = UIImage(data: profilePhotoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
        } else {
            Image(MockData.profileImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
        }
    }

    private var settingsCard: some View {
        VStack(spacing: 20) {
            NavigationLink {
                PreferencesView()
            } label: {
                profileActionLabel(
                    title: "CONSOLE",
                    subtitle: "SET YOUR PREFERENCES",
                    tint: .cyan
                )
            }
            .buttonStyle(.plain)



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
                profileActionLabel(
                    title: "DELETE ACCOUNT",
                    tint: .red,
                    height: 46
                )
            }
            .buttonStyle(.plain)
            .frame(width: 220)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
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

            centeredProfileButton("CHANGE USERNAME", tint: .pink) {
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
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .background(.black.opacity(0.25), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.red.opacity(0.15), lineWidth: 1)
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

            centeredProfileButton("CHANGE PASSWORD", tint: .red) {
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

    private func centeredProfileButton(
        _ title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Spacer()

            Button(action: action) {
                profileActionLabel(title: title, tint: tint, height: 36)
            }
            .buttonStyle(.plain)
            .frame(width: 190)

            Spacer()
        }
    }

    private func profileActionLabel(
        title: String,
        subtitle: String? = nil,
        tint: Color,
        height: CGFloat = 66
    ) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: height)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.18), .white.opacity(0.045)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }

        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
