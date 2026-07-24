import ClerkKit
import ClerkKitUI
import SwiftUI

struct IdentityMenu: View {
    @EnvironmentObject private var auth: AuthController
    @State private var authViewIsPresented = false

    var body: some View {
        Menu {
            settingsContents
        } label: {
            Image(systemName: auth.isSignedIn ? "person.crop.circle.fill" : "gearshape")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onOpenURL { url in
            guard auth.isConfigured else { return }
            Task { try? await Clerk.shared.handle(url) }
        }
        .sheet(isPresented: $authViewIsPresented) {
            if auth.isConfigured {
                AuthView()
                    .persistsIdentifiers(false)
                    .environment(Clerk.shared)
                    .frame(minWidth: 420, minHeight: 520)
            } else {
                ProgressView()
                    .frame(width: 260, height: 160)
            }
        }
    }

    @ViewBuilder
    private var settingsContents: some View {
        Toggle("Open at Login", isOn: Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { LaunchAtLogin.setEnabled($0) }
        ))
        Text("Show TodoBar  ⌃⌥T")
        Text(auth.statusText)

        Divider()

        if auth.canSync {
            if auth.isSignedIn {
                Button("Sign Out") {
                    auth.signOut()
                }
            } else {
                Button("Sign in to Sync") {
                    auth.prepareSync()
                    if auth.isConfigured {
                        authViewIsPresented = true
                    }
                }
            }
            Button("Reset Sync Login") {
                auth.resetSyncSession()
            }
        } else {
            Text("Sync unavailable")
        }

        Button("Quit TodoBar") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

struct LocalSettingsMenu: View {
    var body: some View {
        Menu {
            Toggle("Open at Login", isOn: Binding(
                get: { LaunchAtLogin.isEnabled },
                set: { LaunchAtLogin.setEnabled($0) }
            ))
            Text("Show TodoBar  ⌃⌥T")
            Divider()
            Button("Quit TodoBar") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
