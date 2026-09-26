import Foundation

public enum SpotifyConfig {
    /// Built-in Client ID from https://developer.spotify.com/dashboard.
    /// PKCE apps have no secret; the ID is public by design.
    public static let defaultClientID = "762db0dbb98448faa79031fab61c0b07"

    public static func resolveClientID(custom: String?) -> String {
        guard let custom, !custom.isEmpty else { return defaultClientID }
        return custom
    }

    /// The effective Client ID: the user's own app if they configured one
    /// (Spotify's dev-mode user cap is per app, so "bring your own app"
    /// sidesteps the allowlist), otherwise the built-in app.
    public static var clientID: String {
        resolveClientID(custom: SharedSettings().customClientID)
    }

    public static let redirectURI = "coverwall://callback"
    public static let scopes = "user-read-recently-played user-top-read user-library-read"

    public static func authorizationURL(challenge: String) -> URL {
        var c = URLComponents(string: "https://accounts.spotify.com/authorize")!
        c.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: scopes),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
        ]
        return c.url!
    }
}
