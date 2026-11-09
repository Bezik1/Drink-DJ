import SwiftUI
import UIKit

struct LoginView: View {
    @Binding var session: Session

    @State private var email = MockData.email
    @State private var password = MockData.password
    @State private var showsError = false

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
            } footer: {
                if showsError {
                    Text("Incorrect email or password.")
                        .foregroundStyle(.red)
                }
            }

            Section {
                NavigationLink("Create account") {
                    RegisterView(session: $session)
                }
            }
        }
        .navigationTitle("Welcome back")
        .safeAreaInset(edge: .bottom) {
            FloatingGlassActions {
                GlassActionButton("Log in", isProminent: true, action: logIn)
                GlassActionButton("Sign in with passkey") { session = .signedIn }
                GlassActionButton("Continue as guest") { session = .guest }
            }
        }
    }

    private func logIn() {
        if email == MockData.email && password == MockData.password {
            session = .signedIn
        } else {
            showsError = true
        }
    }
}

#Preview {
    NavigationStack {
        LoginView(session: .constant(.signedOut))
    }
}
