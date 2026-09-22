# Asset Endpoints

Supply, holders, and history for native assets.

## Identifying an Asset

Most asset endpoints take a *unit*: the policy ID concatenated with the hex-encoded asset name.

```swift
let policyId = "d27197682d71905c087c5c3b61b10e6d746db0b9bef351014d75bb26"
let assetNameHex = "4d494e"           // "MIN"
let unit = policyId + assetNameHex
```

Some endpoints also accept a policy ID on its own, or a CIP-14 fingerprint.

## Supply

```swift
let byUnit = try await yaci.client.getSupplyByUnit(path: .init(unit: unit)).ok.body.json
print("\(byUnit.unit ?? ""): \(byUnit.supply ?? 0)")

let byPolicy = try await yaci.client.getSupplyByPolicy(path: .init(policy: policyId)).ok.body.json
let byFingerprint = try await yaci.client.getSupplyByFingerprint(
    path: .init(fingerprint: fingerprint)
).ok.body.json
```

## Holders

```swift
let holders = try await yaci.client.getAddressesByAsset(
    path: .init(unit: unit),
    query: .init(page: 0, count: 100)
).ok.body.json

for holder in holders {
    // AddressAssetBalanceDto.quantity is a String — see <doc:Amounts>
    print("\(holder.address ?? ""): \(holder.quantity ?? "0")")
}
```

## History

Mint and burn history is available by unit, policy, or fingerprint:

```swift
let byUnit = try await yaci.client.getAssetTransactions(
    path: .init(unit: unit),
    query: .init(page: 0, count: 50)
).ok.body.json

let byPolicy = try await yaci.client.getAssetTxsByPolicyId(
    path: .init(policy: policyId),
    query: .init(page: 0, count: 50)
).ok.body.json

let byFingerprint = try await yaci.client.getAssetTxsByFingerprint(
    path: .init(fingerprint: fingerprint),
    query: .init(page: 0, count: 50)
).ok.body.json

// Every asset moved by one transaction
let inTransaction = try await yaci.client.getAssetTxsByTx(path: .init(txHash: txHash)).ok.body.json
```

## Deprecated Paths

Yaci Store still serves older asset routes, and the generator names them with a `Deprecated` suffix — `getSupplyByUnitDeprecated`, `getAssetUtxosDeprecated`, and others. They answer the same data as the current routes. Prefer the ones above.

## Related

- <doc:UtxoEndpoints>
