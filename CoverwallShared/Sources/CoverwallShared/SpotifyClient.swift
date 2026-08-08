import Foundation

private let formUnreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

public enum SpotifyError: Error, Equatable {
    case http(Int)
    case rateLimited(retryAfter: TimeInterval)
    case malformedResponse
}

public struct TokenSet: Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date

    public init(accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    public var isExpired: Bool { Date() > expiresAt.addingTimeInterval(-60) }
}

public struct AlbumRef: Equatable {
    public let albumID: String
    public let title: String
    public let artist: String
    public let imageURL: URL
}

public struct SpotifyClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Auth

    public func exchangeCode(_ code: String, verifier: String) async throws -> TokenSet {
        try await tokenRequest(body: [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConfig.redirectURI,
            "client_id": SpotifyConfig.clientID,
            "code_verifier": verifier,
        ], fallbackRefreshToken: nil)
    }

    public func refresh(_ token: TokenSet) async throws -> TokenSet {
        try await tokenRequest(body: [
            "grant_type": "refresh_token",
            "refresh_token": token.refreshToken,
            "client_id": SpotifyConfig.clientID,
        ], fallbackRefreshToken: token.refreshToken)
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Double
    }

    private func tokenRequest(body: [String: String],
                              fallbackRefreshToken: String?) async throws -> TokenSet {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: formUnreserved) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: formUnreserved) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
            .data(using: .utf8)
        let data = try await perform(request)
        let parsed = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let refresh = parsed.refresh_token ?? fallbackRefreshToken else {
            throw SpotifyError.malformedResponse
        }
        return TokenSet(accessToken: parsed.access_token, refreshToken: refresh,
                        expiresAt: Date(timeIntervalSinceNow: parsed.expires_in))
    }

    // MARK: - Library endpoints

    private struct ImageJSON: Decodable { let url: String; let width: Int?; let height: Int? }
    private struct ArtistJSON: Decodable { let name: String }
    private struct AlbumJSON: Decodable {
        let id: String
        let name: String
        let images: [ImageJSON]
        let artists: [ArtistJSON]
    }
    private struct TrackJSON: Decodable { let album: AlbumJSON }
    private struct PlayHistoryJSON: Decodable { let track: TrackJSON }
    private struct RecentlyPlayedJSON: Decodable { let items: [PlayHistoryJSON] }
    private struct TopTracksJSON: Decodable { let items: [TrackJSON] }
    private struct SavedTrackJSON: Decodable { let track: TrackJSON }
    private struct LikedSongsJSON: Decodable { let items: [SavedTrackJSON]; let next: String? }

    public func recentlyPlayed(accessToken: String) async throws -> [AlbumRef] {
        let data = try await get("https://api.spotify.com/v1/me/player/recently-played?limit=50",
                                 accessToken: accessToken)
        let parsed = try JSONDecoder().decode(RecentlyPlayedJSON.self, from: data)
        return dedupe(parsed.items.map(\.track.album))
    }

    public func topTracks(range: TopTracksRange, accessToken: String) async throws -> [AlbumRef] {
        let data = try await get(
            "https://api.spotify.com/v1/me/top/tracks?limit=50&time_range=\(range.apiValue)",
            accessToken: accessToken)
        let parsed = try JSONDecoder().decode(TopTracksJSON.self, from: data)
        return dedupe(parsed.items.map(\.album))
    }

    public func likedSongs(accessToken: String, pages: Int = 4) async throws -> [AlbumRef] {
        var albums: [AlbumJSON] = []
        var next: String? = "https://api.spotify.com/v1/me/tracks?limit=50"
        var remaining = pages
        while let url = next, remaining > 0 {
            let data = try await get(url, accessToken: accessToken)
            let parsed = try JSONDecoder().decode(LikedSongsJSON.self, from: data)
            albums += parsed.items.map(\.track.album)
            next = parsed.next
            remaining -= 1
        }
        return dedupe(albums)
    }

    public func downloadImage(at url: URL) async throws -> Data {
        try await perform(URLRequest(url: url))
    }

    // MARK: - Plumbing

    private func get(_ urlString: String, accessToken: String) async throws -> Data {
        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SpotifyError.malformedResponse }
        if http.statusCode == 429 {
            let retry = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 30
            throw SpotifyError.rateLimited(retryAfter: retry)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SpotifyError.http(http.statusCode)
        }
        return data
    }

    private func dedupe(_ albums: [AlbumJSON]) -> [AlbumRef] {
        var seen = Set<String>()
        var result: [AlbumRef] = []
        for album in albums where !seen.contains(album.id) {
            let best = album.images.max { ($0.width ?? 0) < ($1.width ?? 0) }
            guard let best, let url = URL(string: best.url) else { continue }
            seen.insert(album.id)
            result.append(AlbumRef(albumID: album.id, name: album.name, artist: album.artists.first?.name ?? "", imageURL: url))
        }
        return result
    }
}

private extension AlbumRef {
    init(albumID: String, name: String, artist: String, imageURL: URL) {
        self.init(albumID: albumID, title: name, artist: artist, imageURL: imageURL)
    }
}
