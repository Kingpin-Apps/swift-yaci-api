# Testing

Test against fixtures with no network, or against a real instance.

## Injecting a Transport

``Yaci/init(basePath:apiKey:environmentVariable:client:)`` accepts a pre-built `Client`, so you can answer requests from fixtures instead of the network. Implement `ClientTransport` and dispatch on the operation ID:

```swift
import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import SwiftYaciAPI

struct StubTransport: ClientTransport {
    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard operationID == Operations.GetLatestBlock.id else {
            return (HTTPResponse(status: .notFound), nil)
        }
        let json = #"{"number": 1234567, "epoch": 152, "fees": "2134567"}"#
        return (
            HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]),
            .init(Data(json.utf8))
        )
    }
}

@Test func latestBlock() async throws {
    let yaci = try Yaci(
        client: Client(serverURL: Yaci.defaultServerURL, transport: StubTransport())
    )
    let block = try await yaci.client.getLatestBlock().ok.body.json
    #expect(block.number == 1234567)
}
```

Keying fixtures by `Operations.X.id` rather than a string literal means a renamed operation breaks the build instead of silently falling through to a `404`.

## Writing Fixtures as JSON

Prefer raw JSON over building the generated model and re-encoding it. JSON exercises the generated `CodingKeys`, so a snake_case mapping that does not match the server fails the test — which is exactly the class of bug worth catching.

## Asserting on Requests

Record what the client sent, and assert on the URL, query and headers it built:

```swift
final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [HTTPRequest] = []

    var last: HTTPRequest? {
        lock.lock()
        defer { lock.unlock() }
        return storage.last
    }

    func record(_ request: HTTPRequest) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(request)
    }
}
```

`ClientTransport.send` is not isolated to an actor, so guard shared state with a lock rather than assuming the main actor.

## Testing Against a Real Instance

The package's own integration suite runs against a live store and is skipped unless `YACI_BASE_URL` is set, so `swift test` stays hermetic by default:

```bash
YACI_BASE_URL=http://localhost:8080 swift test
```

Tests that need indexed data discover it from the store — reading a transaction hash from the transaction list, and an address from that transaction's outputs — rather than hard-coding values that only exist on one chain.

Submission is covered too. Submitting spends the transaction's input, so a fresh signed transaction is needed for each run; `scripts/devkit-signed-tx.sh` builds one against a running [Yaci DevKit](https://github.com/bloxbean/yaci-devkit):

```bash
export YACI_TEST_TX_HEX="$(./scripts/devkit-signed-tx.sh)"
YACI_BASE_URL=http://localhost:8080 swift test
```

That test evaluates the transaction, submits it, then polls until the store indexes it — an end-to-end check that the bytes reached the chain.

## Related

- <doc:ClientConfiguration>
- <doc:ErrorHandling>
