# Script Endpoints

Look up scripts and datums by hash.

## Scripts

```swift
let script = try await yaci.client.getScriptByHash(path: .init(scriptHash: scriptHash)).ok.body.json

print("Type: \(script._type?.rawValue ?? "unknown")")   // timelock, plutusV1, plutusV2, plutusV3
print("Size: \(script.serialisedSize ?? 0) bytes")
```

`ScriptDto._type` carries a leading underscore because `type` is a Swift keyword; the generator renames it. Its raw values are `timelock`, `plutusV1`, `plutusV2` and `plutusV3`.

The script body is available in either form:

```swift
let json = try await yaci.client.getScriptJsonByHash(path: .init(scriptHash: scriptHash)).ok.body.json
let cbor = try await yaci.client.getScriptCborByHash(path: .init(scriptHash: scriptHash)).ok.body.json
let details = try await yaci.client.getScriptDetailsByHash(path: .init(scriptHash: scriptHash)).ok.body.json
```

Native scripts have a meaningful JSON form; Plutus scripts are best fetched as CBOR.

## Datums

```swift
let json = try await yaci.client.getDatumJsonByHash(path: .init(datumHash: datumHash)).ok.body.json
let cbor = try await yaci.client.getDatumCborByHash(path: .init(datumHash: datumHash)).ok.body.json
```

## Missing Scripts

A hash the store has not indexed answers `404`, which arrives as `.undocumented`:

```swift
switch try await yaci.client.getScriptByHash(path: .init(scriptHash: hash)) {
case .ok(let response):
    return try response.body.json
case .undocumented(404, _):
    return nil
case .undocumented(let statusCode, _):
    throw MyError.unexpectedStatus(statusCode)
}
```

## Related

- <doc:TransactionEndpoints>
- <doc:ErrorHandling>
