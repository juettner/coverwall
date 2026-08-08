import AppKit
import AuthenticationServices
import CoverwallShared

final class AuthController: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var activeSession: ASWebAuthenticationSession?

    func authorize() async throws -> TokenSet {
        let pkce = PKCE()
        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: SpotifyConfig.authorizationURL(challenge: pkce.challenge),
                callbackURLScheme: "coverwall") { [weak self] url, error in
                self?.activeSession = nil
                if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: error ?? URLError(.userCancelledAuthentication)) }
            }
            session.presentationContextProvider = self
            activeSession = session
            session.start()
        }
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw URLError(.badServerResponse)
        }
        return try await SpotifyClient().exchangeCode(code, verifier: pkce.verifier)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.makeKeyAndOrderFront(nil)
        return window
    }
}
