import Foundation

public struct StarterTrack: Equatable {
    public let artist: String
    public let title: String
    public let trackID: String

    public init(artist: String, title: String, trackID: String) {
        self.artist = artist
        self.title = title
        self.trackID = trackID
    }
}

/// A snapshot of the Spotify global daily top tracks, baked in at release
/// time so fresh installs show real, current album art before anyone logs
/// in. Live chart access isn't possible without a user token (Spotify
/// removed chart/editorial endpoints for new apps), so this list is
/// refreshed manually with each release.
///
/// Snapshot date: 2026-08-08 (global daily chart).
public enum StarterSet {
    public static let tracks: [StarterTrack] = [
        .init(artist: "Ariana Grande", title: "hate that i made you love me", trackID: "20jbSiX29FDX4oQxBXyUEi"),
        .init(artist: "Shakira", title: "Dai Dai", trackID: "0kosUz0jePvjiz4ctmR6wL"),
        .init(artist: "Ariana Grande", title: "petal", trackID: "70pVCVMGjmIWPbWXDwf11e"),
        .init(artist: "Justin Bieber", title: "Beauty And A Beat", trackID: "6QFCMUUq1T2Vf5sFUXcuQ7"),
        .init(artist: "Malcolm Todd", title: "Earrings", trackID: "0eAuGrXyGFYwur9ARUe7LJ"),
        .init(artist: "Katy Perry", title: "The One That Got Away", trackID: "6hkOqJ5mE093AQf2lbZnsG"),
        .init(artist: "BTS", title: "SWIM", trackID: "68lbSrXDORS51pmyjZv712"),
        .init(artist: "Dominic Fike", title: "Babydoll", trackID: "7yNf9YjeO5JXUE3JEBgnYc"),
        .init(artist: "Temper City", title: "Self Aware", trackID: "4qW3BbQAwZsrnu8a3ZRdyT"),
        .init(artist: "Michael Jackson", title: "Billie Jean", trackID: "7J1uxwnxfQLu4APicE5Rnj"),
        .init(artist: "Tame Impala", title: "Loser", trackID: "7bxaFZ1O3cHkgLKMsdC3xR"),
        .init(artist: "KATSEYE", title: "Animal", trackID: "3ouNEk0tv5TTi8VWMe1xbX"),
        .init(artist: "sombr", title: "back to friends", trackID: "7qjZnBKE73H4Oxkopwulqe"),
        .init(artist: "Oasis", title: "Wonderwall", trackID: "5qqabIl2vWzo9ApSC317sa"),
        .init(artist: "Olivia Rodrigo", title: "stupid song", trackID: "49j6SvuvWfbEKZKzsHCdLJ"),
        .init(artist: "The Goo Goo Dolls", title: "Iris", trackID: "6Qyc6fS4DsZjB2mRW9DsQs"),
        .init(artist: "Olivia Rodrigo", title: "the cure", trackID: "55pBIZO1cqoldeqpp5WR7H"),
        .init(artist: "Ella Langley", title: "Choosin' Texas", trackID: "7scFxt9VhL4FJwuPSfRlfN"),
        .init(artist: "Djo", title: "End of Beginning", trackID: "3qhlB30KknSejmIvZZLjOD"),
        .init(artist: "Ravyn Lenae", title: "Love Me Not", trackID: "4WFgvKVfEhb3IUAFGrutTR"),
        .init(artist: "Olivia Dean", title: "Man I Need", trackID: "1qbmS6ep2hbBRaEZFpn7BX"),
        .init(artist: "Lady Gaga", title: "Die With A Smile", trackID: "2plbrEY59IikOBgBGLjaoe"),
        .init(artist: "Olivia Rodrigo", title: "drop dead", trackID: "3fRCAPMMZ8l8P9YKI6OCzD"),
        .init(artist: "Alex Warren", title: "Ordinary", trackID: "2RkZ5LkEzeHGRsmDqKwmaJ"),
        .init(artist: "Michael Jackson", title: "Beat It", trackID: "3BovdzfaX4jb5KFQwoPfAw"),
        .init(artist: "Taylor Swift", title: "The Fate of Ophelia", trackID: "53iuhJlwXhSER5J2IYYv1W"),
        .init(artist: "The Neighbourhood", title: "Sweater Weather", trackID: "2QjOHCTQ1Jl3zawyYOpxh6"),
        .init(artist: "Post Malone", title: "Sunflower", trackID: "0RiRZpuVRbi7oqRdSMwhQY"),
        .init(artist: "Gigi Perez", title: "Sailor Song", trackID: "21IYMdzTrzSe191Cy5eMap"),
        .init(artist: "Bad Bunny", title: "DtMF", trackID: "3sK8wGT43QFpWrvNQsrQya"),
        .init(artist: "HUGEL", title: "Jamaican (Bam Bam)", trackID: "7e4zDInS6tA2jwzphvs2Ay"),
        .init(artist: "Billie Eilish", title: "BIRDS OF A FEATHER", trackID: "6dOtVTDdiauQNBQEDOtlAB"),
        .init(artist: "Shawn Mendes", title: "Treat You Better", trackID: "3QGsuHI8jO1Rx4JWLUh9jd"),
        .init(artist: "Bad Bunny", title: "EoO", trackID: "6J5kc12BW5HuP3d7C3vvx8"),
        .init(artist: "Harry Styles", title: "Sign of the Times", trackID: "5Ohxk2dO5COHF1krpoPigN"),
        .init(artist: "eńau", title: "Sesi Potret", trackID: "4xoY4lZNoTjEuHsSmhgF1G"),
        .init(artist: "The Killers", title: "Mr. Brightside", trackID: "003vvx7Niy0yvhvHt4a68B"),
        .init(artist: "Bruno Mars", title: "Locked out of Heaven", trackID: "5g7sDjBhZ4I3gcFIpkrLuI"),
        .init(artist: "Olivia Dean", title: "So Easy (To Fall In Love)", trackID: "6sGIMrtIzQjdzNndVxe397"),
        .init(artist: "Vance Joy", title: "Riptide", trackID: "7yq4Qj7cqayVTp3FF9CWbm"),
        .init(artist: "Bruno Mars", title: "Risk It All", trackID: "5y2ijHECwFYWqcAHKTZgzD"),
        .init(artist: "The Police", title: "Every Breath You Take", trackID: "1JSTJqkT5qHq8MDJnJbRE1"),
        .init(artist: "Zara Larsson", title: "Lush Life", trackID: "1rIKgCH4H52lrvDcz50hS8"),
        .init(artist: "BTS", title: "NORMAL", trackID: "4B4Q7zfd0aHcuhQBfCRnH5"),
        .init(artist: "Mac Miller", title: "Cinderella", trackID: "2lpygKqzPFtItQ4ss3cgfb"),
    ]
}

public protocol StarterArtFetching {
    func coverURL(forTrackID id: String) async throws -> URL
    func downloadImage(at url: URL) async throws -> Data
}

/// Fetches album art for starter tracks via Spotify's public, documented
/// oEmbed endpoint — the one Spotify surface that needs no auth. Used only
/// before login; every logged-in fetch goes through SpotifyClient.
public struct StarterArtClient: StarterArtFetching {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    private struct OEmbedJSON: Decodable {
        let thumbnail_url: String?
    }

    public func coverURL(forTrackID id: String) async throws -> URL {
        var components = URLComponents(string: "https://open.spotify.com/oembed")!
        components.queryItems = [.init(name: "url", value: "https://open.spotify.com/track/\(id)")]
        let data = try await perform(URLRequest(url: components.url!))
        let parsed = try JSONDecoder().decode(OEmbedJSON.self, from: data)
        guard let raw = parsed.thumbnail_url, let url = URL(string: raw) else {
            throw SpotifyError.malformedResponse
        }
        return url
    }

    public func downloadImage(at url: URL) async throws -> Data {
        try await perform(URLRequest(url: url))
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw SpotifyError.malformedResponse
        }
        return data
    }
}
