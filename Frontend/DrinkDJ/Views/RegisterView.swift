import SwiftUI
import UIKit

struct RegisterView: View {
    @Binding var session: Session

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var repeatedPassword = ""

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                SecureField("Repeat password", text: $repeatedPassword)
            } footer: {
                if !repeatedPassword.isEmpty {
                    Text(password == repeatedPassword ? "Passwords match" : "Passwords don't match")
                }
            }

            Section {
                Button("Already have an account? Log in") { dismiss() }
            }
        }
        .navigationTitle("Create account")
        .safeAreaInset(edge: .bottom) {
            FloatingGlassActions {
                GlassActionButton("Create account", isProminent: true) { session = .signedIn }
                GlassActionButton("Continue as guest") { session = .guest }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView(session: .constant(.signedOut))
    }
}
