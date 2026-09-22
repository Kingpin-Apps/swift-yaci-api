import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes

/// A client middleware that injects an `Authorization` header field into every outgoing request.
package struct AuthenticationMiddleware: Sendable {
    /// The formatted value for the `Authorization` header field.
    private let authorization: String

    /// Creates a new middleware.
    /// - Parameter authorization: The raw API key or token string.
    package init(authorizationHeaderFieldValue authorization: String) {
        if authorization.lowercased().hasPrefix("bearer ") {
            self.authorization = authorization
        } else {
            self.authorization = "Bearer \(authorization)"
        }
    }
}

extension AuthenticationMiddleware: ClientMiddleware {
    package func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = authorization
        return try await next(request, body, baseURL)
    }
}

/// A type-safe Swift client for interacting with Yaci Store API instances.
///
/// `Yaci` wraps the OpenAPI-generated `Client` and provides default connection parameters,
/// base URL resolution, optional authentication middleware, and injected `Client` support.
public struct Yaci: Sendable {
    /// The default base URL for a local Yaci Store instance (`http://localhost:8080`).
    public static let defaultServerURL = URL(string: "http://localhost:8080")!

    /// The underlying generated OpenAPI client.
    public let client: Client

    /// The optional API key used for authenticated requests.
    public let apiKey: String?

    /// The base server URL targeting the Yaci Store instance.
    public let baseURL: URL

    /// Creates a new Yaci client.
    ///
    /// - Parameters:
    ///   - basePath: Optional absolute base URL string, including a scheme and host.
    ///     If `nil`, defaults to `http://localhost:8080`.
    ///   - apiKey: Optional API key or bearer token to authenticate requests.
    ///   - environmentVariable: Optional environment variable name to read the API key from if `apiKey` is `nil`.
    ///   - client: Optional pre-configured `Client`, useful for testing with a mock transport.
    /// - Throws: ``YaciAPIError/invalidBasePath(_:)`` if `basePath` is not an absolute URL,
    ///   or ``YaciAPIError/missingAPIKey(_:)`` if `environmentVariable` is specified but not found.
    public init(
        basePath: String? = nil,
        apiKey: String? = nil,
        environmentVariable: String? = nil,
        client: Client? = nil
    ) throws {
        if let apiKey = apiKey {
            self.apiKey = apiKey
        } else if let environmentVariable = environmentVariable {
            guard let envVal = ProcessInfo.processInfo.environment[environmentVariable],
                  !envVal.isEmpty else {
                throw YaciAPIError.missingAPIKey("Environment variable \(environmentVariable) is not set or empty.")
            }
            self.apiKey = envVal
        } else {
            self.apiKey = nil
        }

        if let basePath = basePath {
            guard let url = URL(string: basePath), url.scheme != nil, url.host != nil else {
                throw YaciAPIError.invalidBasePath(
                    "Invalid base path: \(basePath). Expected an absolute URL such as http://localhost:8080."
                )
            }
            self.baseURL = url
        } else {
            self.baseURL = Self.defaultServerURL
        }

        if let client = client {
            self.client = client
        } else {
            var middlewares: [any ClientMiddleware] = []
            if let apiKey = self.apiKey {
                middlewares.append(AuthenticationMiddleware(authorizationHeaderFieldValue: apiKey))
            }
            self.client = Client(
                serverURL: self.baseURL,
                transport: URLSessionTransport(),
                middlewares: middlewares
            )
        }
    }
}
