import Foundation

/// Tiny async HTTP layer with a polite User-Agent (required by Wikimedia and
/// good manners everywhere) and automatic retry on transient failures — NASA's
/// APOD endpoint in particular is prone to brief 5xx/timeout hiccups.
enum HTTPClient {
    static let userAgent =
        "Caelum/1.0 (macOS; +https://github.com/ProfessorEngineergit/caelum)"

    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": userAgent,
                                        "Accept": "application/json, application/rss+xml, */*"]
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadRevalidatingCacheData
        return URLSession(configuration: config)
    }()

    private static let maxAttempts = 3

    static func data(from url: URL) async throws -> Data {
        var attempt = 0
        while true {
            attempt += 1
            do {
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse {
                    let code = http.statusCode
                    if (code >= 500 || code == 429), attempt < maxAttempts {
                        try await backoff(attempt); continue
                    }
                    if !(200..<300).contains(code) { throw SourceError.http(code) }
                }
                return data
            } catch let error as URLError where isTransient(error) && attempt < maxAttempts {
                try await backoff(attempt); continue
            }
        }
    }

    static func json<T: Decodable>(_ type: T.Type,
                                   from url: URL,
                                   decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let data = try await data(from: url)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SourceError.decoding(String(describing: error))
        }
    }

    static func string(from url: URL) async throws -> String {
        String(decoding: try await data(from: url), as: UTF8.self)
    }

    // MARK: - Retry helpers

    private static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    private static func backoff(_ attempt: Int) async throws {
        let seconds = 0.6 * pow(2.0, Double(attempt - 1))   // 0.6s, 1.2s, …
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
