# Client Configuration

Point the client at an instance, authenticate, and supply your own transport.

## Base URL

``Yaci`` connects to `http://localhost:8080` unless you say otherwise. That default is available as ``Yaci/defaultServerURL``:

```swift
let local = try Yaci()
print(local.baseURL)  // http://localhost:8080

let remote = try Yaci(basePath: "https://yaci.example.com:8080")
```

`basePath` must be an absolute URL with both a scheme and a host. A value like `"localhost:8080"` is rejected with ``YaciAPIError/invalidBasePath(_:)`` rather than being turned into a relative URL that fails later, at request time, with a confusing transport error.

## Authentication

Yaci Store does not authenticate requests. If you have put an instance behind a gateway that expects a bearer token, supply one:

```swift
// Explicit token
let yaci = try Yaci(
    basePath: "https://yaci.example.com",
    apiKey: "your-token-here"
)

// Or read it from the environment at initialization
let fromEnvironment = try Yaci(
    basePath: "https://yaci.example.com",
    environmentVariable: "YACI_API_KEY"
)
```

The token is sent as `Authorization: Bearer <token>` on every request. A value that already begins with `Bearer ` (in any case) is passed through unchanged, so you can hand over a pre-formatted header value.

When `environmentVariable` names a variable that is unset or empty, initialization throws ``YaciAPIError/missingAPIKey(_:)``. An explicit `apiKey` takes precedence and the environment is not consulted.

## Injecting a Client

Pass your own `Client` to control the transport — for tests, for a custom `URLSession` configuration, or to add middleware:

```swift
import OpenAPIURLSession

let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 30

let yaci = try Yaci(
    basePath: "https://yaci.example.com",
    client: Client(
        serverURL: URL(string: "https://yaci.example.com")!,
        transport: URLSessionTransport(
            configuration: .init(session: URLSession(configuration: configuration))
        )
    )
)
```

An injected client is used exactly as given. SwiftYaciAPI does not add its authentication middleware to it, so include your own if you need one. The `serverURL` you pass to `Client` is what requests actually go to; `basePath` only sets ``Yaci/baseURL``.

See <doc:Testing> for using this to test without a running instance.

## Concurrency

``Yaci`` is `Sendable` and holds no mutable state, so a single instance can be shared across tasks and actors:

```swift
let yaci = try Yaci()

async let latest = yaci.client.getLatestBlock()
async let params = yaci.client.getLatestProtocolParams()

let (block, protocolParams) = try await (latest.ok.body.json, params.ok.body.json)
```
