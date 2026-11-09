import SwiftUI

enum Session {
    case signedOut, guest, signedIn
}

struct ContentView: View {
    @State private var session = Session.signedOut

    var body: some View {
        if session == .signedOut {
            NavigationStack {
                LoginView(session: $session)
            }
        } else {
            MainMenuView(session: $session)
        }
    }
}

struct MainMenuView: View {
    @Binding var session: Session

    var body: some View {
        TabView {
            Tab("Library", systemImage: "wineglass") {
                ContentUnavailableView(
                    "Library",
                    systemImage: "wineglass",
                    description: Text("Not part of this prototype yet.")
                )
            }
            Tab("Mixer", systemImage: "slider.vertical.3") {
                NavigationStack {
                    MixerView(mix: MockData.newMix)
                }
            }
            Tab("Albums", systemImage: "list.star") {
                NavigationStack {
                    List {
                        NavigationLink("Blue Lagoon Dub") {
                            MixerView(mix: MockData.blueLagoonDub)
                        }
                        NavigationLink("Console") {
                            PreferencesView()
                        }
                    }
                    .navigationTitle("Albums")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Log out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                                session = .signedOut
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
