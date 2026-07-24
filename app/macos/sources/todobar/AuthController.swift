import ClerkConvex
import ClerkKit
@preconcurrency import ConvexMobile
import Foundation

@MainActor
final class AuthController: ObservableObject {
    @Published var statusText = "Local mode"
    @Published private(set) var isConfigured = false
    @Published private(set) var isSignedIn = false
    @Published private(set) var errorMessage: String?

    var onRepositoryReady: ((any TaskRepository) -> Void)?
    var onSignedOut: (() -> Void)?

    private let config: AppConfig
    private var client: ConvexClientWithAuth<String>?
    private var repository: ConvexTaskRepository?
    private var authEventsTask: Task<Void, Never>?

    init(config: AppConfig) {
        self.config = config
    }

    var canSync: Bool {
        config.isCloudConfigured
    }

    func prepareSync() {
        guard config.isCloudConfigured else {
            errorMessage = "Missing Clerk or Convex configuration."
            statusText = "Sync unavailable"
            return
        }

        guard !isConfigured else { return }
        guard let publishableKey = config.clerkPublishableKey, let convexUrl = config.convexUrl else { return }

        let keychainService = "\(Bundle.main.bundleIdentifier ?? "com.hasanshoaib.todobar").sync.v1"
        let options = Clerk.Options(
            telemetryEnabled: false,
            keychainConfig: .init(service: keychainService),
            redirectConfig: .init(
                redirectUrl: "com.hasanshoaib.todobar://callback",
                callbackUrlScheme: "com.hasanshoaib.todobar"
            )
        )

        Clerk.configure(publishableKey: publishableKey, options: options)
        let provider = ClerkConvexAuthProvider()
        let client = ConvexClientWithAuth(deploymentUrl: convexUrl, authProvider: provider)
        let repository = ConvexTaskRepository(client: client)
        self.client = client
        self.repository = repository
        isConfigured = true
        statusText = "Sign in to sync"
        observeAuthEvents()
        handle(session: Clerk.shared.session)
    }

    func signOut() {
        guard isConfigured else { return }
        Task {
            try? await Clerk.shared.auth.signOut()
            await client?.logout()
            isSignedIn = false
            statusText = "Local mode"
            onSignedOut?()
        }
    }

    func resetSyncSession() {
        guard isConfigured else {
            prepareSync()
            guard isConfigured else { return }
            Clerk.clearAllKeychainItems()
            statusText = "Sync reset"
            return
        }
        Clerk.clearAllKeychainItems()
        isSignedIn = false
        statusText = "Sync reset"
        onSignedOut?()
    }

    private func observeAuthEvents() {
        authEventsTask?.cancel()
        authEventsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in Clerk.shared.auth.events {
                guard !Task.isCancelled else { break }
                if case .sessionChanged(_, let newSession) = event {
                    handle(session: newSession)
                }
            }
        }
    }

    private func handle(session: Session?) {
        guard let session, session.status == .active, let repository else {
            isSignedIn = false
            if isConfigured {
                statusText = "Sign in to sync"
            }
            return
        }

        isSignedIn = true
        statusText = "Synced"
        onRepositoryReady?(repository)
    }
}
