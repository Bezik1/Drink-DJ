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
    @State private var selectedTab = MainTab.home
    @State private var librarySearchActivationID = 0
    @State private var selectedMix = MockData.newMix

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                NavigationStack {
                    LibraryView(
                        mode: .home,
                        searchActivationID: 0,
                        openLibrary: openLibrarySearch,
                        openMixer: openMixer,
                        openAlbums: openAlbums
                    )
                }
            }

            Tab("Library", systemImage: "wineglass", value: .library) {
                NavigationStack {
                    LibraryView(
                        mode: .library,
                        searchActivationID: librarySearchActivationID,
                        openLibrary: {},
                        openMixer: openMixer,
                        openAlbums: openAlbums
                    )
                }
            }

            Tab("Mixer", systemImage: "slider.vertical.3", value: .mixer) {
                NavigationStack {
                    MixerView(mix: selectedMix)
                        .id(selectedMix.name)
                }
            }

            Tab("Albums", systemImage: "list.star", value: .albums) {
                NavigationStack {
                    AlbumsView()
                /*
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
                 */
                }
            }
        }
    }

    private func openLibrarySearch() {
        selectedTab = .library
        librarySearchActivationID += 1
    }

    private func openMixer(_ mix: Mix) {
        selectedMix = mix
        selectedTab = .mixer
    }

    private func openAlbums() {
        selectedTab = .albums
    }
}

private enum MainTab: Hashable {
    case home
    case library
    case mixer
    case albums
}

#Preview {
    ContentView()
}
