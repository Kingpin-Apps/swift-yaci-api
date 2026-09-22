# Error Handling

Configuration failures, non-success responses, and the quirks a real instance has.

## Configuration Errors

Creating a ``Yaci`` throws ``YaciAPIError``:

```swift
do {
    let yaci = try Yaci(basePath: basePath, environmentVariable: "YACI_API_KEY")
} catch let error as YaciAPIError {
    switch error {
    case .invalidBasePath: print("Bad base path: \(error)")
    case .missingAPIKey:   print("Missing API key: \(error)")
    case .valueError:      print("Bad value: \(error)")
    }
}
```

``YaciAPIError`` is `Equatable` and `CustomStringConvertible`, so it compares cleanly in tests and prints a usable message — either the one attached to the case, or a default.

## Response Errors

Operations do not throw on a non-success status. They return an output enum with a case per documented status, plus `.undocumented` for everything else:

```swift
switch try await yaci.client.getTransaction(path: .init(txHash: txHash)) {
case .ok(let response):
    let transaction = try response.body.json
    print(transaction.hash ?? "")
case .undocumented(let statusCode, let payload):
    let detail = try await String(collecting: payload.body ?? .init(""), upTo: 8192)
    print("Yaci Store returned \(statusCode): \(detail)")
}
```

When any non-success is simply an error for your purposes, `.ok` throws and keeps the call site short:

```swift
let transaction = try await yaci.client.getTransaction(path: .init(txHash: txHash)).ok.body.json
```

Use the switch when you need to tell "not found" apart from "something went wrong" — a `404` for an unknown hash usually deserves `nil`, not a thrown error.

## Success Is Not Always 200

`submitTx1`, `evaluateTx` and `evaluateTx1` answer **`202 Accepted`** on success. Their outputs carry both `.ok` and `.accepted`, and `.ok` throws on a `202`:

```swift
let hash = try submitted.accepted.body.json
```

See <doc:TransactionEndpoints>.

## Decoding Errors

A response whose body does not match the schema throws a `ClientError` wrapping a `DecodingError`. The error names the operation, the field and the received body, which is usually enough to identify the mismatch:

```
DecodingError: typeMismatch Int - at CodingKeys(stringValue: "output"):
Expected to decode Int but found a string instead. …operationID: getLatestBlock
```

If you hit one of these, the bundled specification and the instance disagree about a field. <doc:SpecificationFixes> describes the ones already corrected and how to add another.

## Known Yaci Store Behaviours

Two server behaviours are worth guarding against. Neither is worked around in this package, because both are the server's to fix:

- **`getStakeAddressBalance`** answers `200` with a body of literal `null` for a stake address it has not indexed, instead of `404`. Decoding throws a `DecodingError` reporting a `null` value. Catch it, or confirm the account exists first.
- **`getStakeAccountDetails`** answers `500` for an unknown stake address, arriving as `.undocumented(statusCode: 500, _)`.

```swift
func balance(for stakeAddress: String) async throws -> Components.Schemas.StakeAddressBalance? {
    do {
        return try await yaci.client
            .getStakeAddressBalance(path: .init(stakeAddress: stakeAddress))
            .ok.body.json
    } catch {
        // A null body for an unknown account decodes as a failure.
        return nil
    }
}
```

## Transport Errors

Network failures surface as thrown errors from the underlying transport — a refused connection when the instance is down, a timeout when it is slow. These are ordinary `URLError`s wrapped by the OpenAPI runtime, and they are worth separating from protocol-level failures when you retry.

## Related

- <doc:TransactionEndpoints>
- <doc:Testing>
