import Foundation

struct AccrueSDKURLs: Decodable {
    let production: String
    let sandbox: String
}

enum AccrueSDKURLResolverError: Error {
    case invalidURLConfigurationEndpoint
    case invalidWidgetURL(String)
}

struct AccrueWidgetURLBuilder {
    static func buildURL(
        sdkURLs: AccrueSDKURLs,
        isSandbox: Bool,
        overrideURL: String?,
        merchantId: String,
        redirectionToken: String?
    ) throws -> URL {
        let rawBaseURL: String

        if isSandbox {
            rawBaseURL = sdkURLs.sandbox
        } else if let overrideURL = overrideURL,
            !overrideURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            rawBaseURL = overrideURL
        } else {
            rawBaseURL = sdkURLs.production
        }

        return try buildURL(
            baseURLString: rawBaseURL,
            merchantId: merchantId,
            redirectionToken: redirectionToken
        )
    }

    static func buildURL(
        baseURLString: String,
        merchantId: String,
        redirectionToken: String?
    ) throws -> URL {
        let trimmedBaseURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard var urlComponents = URLComponents(string: trimmedBaseURL) else {
            throw AccrueSDKURLResolverError.invalidWidgetURL(baseURLString)
        }

        if urlComponents.path.isEmpty || urlComponents.path == "/" {
            urlComponents.path = "/webview"
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "merchantId", value: merchantId)
        ]

        if let redirectionToken = redirectionToken {
            urlComponents.queryItems?.append(
                URLQueryItem(name: "redirectionToken", value: redirectionToken))
        }

        guard let url = urlComponents.url else {
            throw AccrueSDKURLResolverError.invalidWidgetURL(baseURLString)
        }

        return url
    }

    static func buildFallbackURL(
        isSandbox: Bool,
        merchantId: String,
        redirectionToken: String?
    ) throws -> URL {
        try buildURL(
            baseURLString: isSandbox ? AppConstants.sandboxUrl : AppConstants.productionUrl,
            merchantId: merchantId,
            redirectionToken: redirectionToken
        )
    }
}

final class AccrueSDKURLResolver {
    static let shared = AccrueSDKURLResolver()

    private let endpoint: URL
    private let session: URLSession
    private let queue = DispatchQueue(label: "com.byaccrue.ios-sdk.url-resolver")
    private var cachedURLs: AccrueSDKURLs?
    private var pendingCompletions: [(Result<AccrueSDKURLs, Error>) -> Void] = []

    init(
        endpoint: URL = URL(string: AppConstants.sdkUrlsEndpoint)!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func resolveWidgetURL(
        isSandbox: Bool,
        overrideURL: String?,
        merchantId: String,
        redirectionToken: String?,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if !isSandbox,
            let overrideURL = overrideURL,
            !overrideURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            completeOnMain(
                tryResult {
                    try AccrueWidgetURLBuilder.buildURL(
                        baseURLString: overrideURL,
                        merchantId: merchantId,
                        redirectionToken: redirectionToken
                    )
                }.map { resolvedURL in
                    print("🔗 AccrueSDKURLResolver resolved widget URL from override: \(resolvedURL)")
                    return resolvedURL
                },
                completion: completion
            )
            return
        }

        fetchSDKURLs { result in
            let widgetURLResult = result.flatMap { sdkURLs in
                self.tryResult {
                    try AccrueWidgetURLBuilder.buildURL(
                        sdkURLs: sdkURLs,
                        isSandbox: isSandbox,
                        overrideURL: overrideURL,
                        merchantId: merchantId,
                        redirectionToken: redirectionToken
                    )
                }
            }

            switch widgetURLResult {
            case .success(let resolvedURL):
                print("🔗 AccrueSDKURLResolver resolved widget URL from remote config: \(resolvedURL)")
                completion(widgetURLResult)
            case .failure(let error):
                let fallbackURLResult = self.tryResult {
                    try AccrueWidgetURLBuilder.buildFallbackURL(
                        isSandbox: isSandbox,
                        merchantId: merchantId,
                        redirectionToken: redirectionToken
                    )
                }

                if case .success(let fallbackURL) = fallbackURLResult {
                    print(
                        "⚠️ AccrueSDKURLResolver failed to resolve remote widget URL: \(error). Using fallback URL: \(fallbackURL)"
                    )
                }

                completion(fallbackURLResult)
            }
        }
    }

    private func fetchSDKURLs(completion: @escaping (Result<AccrueSDKURLs, Error>) -> Void) {
        queue.async {
            if let cachedURLs = self.cachedURLs {
                self.completeOnMain(.success(cachedURLs), completion: completion)
                return
            }

            self.pendingCompletions.append(completion)

            guard self.pendingCompletions.count == 1 else {
                return
            }

            let task = self.session.dataTask(with: self.endpoint) { data, _, error in
                let result: Result<AccrueSDKURLs, Error>

                if let error = error {
                    result = .failure(error)
                } else if let data = data {
                    result = self.tryResult {
                        try JSONDecoder().decode(AccrueSDKURLs.self, from: data)
                    }
                } else {
                    result = .failure(AccrueSDKURLResolverError.invalidURLConfigurationEndpoint)
                }

                self.queue.async {
                    if case .success(let sdkURLs) = result {
                        self.cachedURLs = sdkURLs
                    }

                    let completions = self.pendingCompletions
                    self.pendingCompletions.removeAll()

                    completions.forEach { pendingCompletion in
                        self.completeOnMain(result, completion: pendingCompletion)
                    }
                }
            }

            task.resume()
        }
    }

    private func tryResult<T>(_ body: () throws -> T) -> Result<T, Error> {
        do {
            return .success(try body())
        } catch {
            return .failure(error)
        }
    }

    private func completeOnMain<T>(
        _ result: Result<T, Error>,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }
}
