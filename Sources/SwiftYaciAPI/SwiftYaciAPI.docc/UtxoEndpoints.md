# UTxO Endpoints

Look up unspent outputs by address, by key, or by the asset they hold.

## UTxOs at an Address

```swift
let utxos = try await yaci.client.getUtxos1(
    path: .init(address: address),
    query: .init(count: 100, page: 0, order: .desc)
).ok.body.json

for utxo in utxos {
    let lovelace = Int(utxo.amount?.first(where: { $0.unit == "lovelace" })?.quantity ?? "0") ?? 0
    print("\(utxo.txHash ?? "")#\(utxo.outputIndex ?? 0): \(lovelace) lovelace")
}
```

> Note: `Utxo.amount` quantities are `String`. See <doc:Amounts>.

## A Specific Output

```swift
let utxo = try await yaci.client.getUtxo(path: .init(txHash: txHash, index: 0)).ok.body.json

print("Owner:    \(utxo.ownerAddr ?? "")")
print("Lovelace: \(utxo.lovelaceAmount ?? 0)")
print("Datum:    \(utxo.inlineDatum ?? utxo.dataHash ?? "none")")
```

This endpoint returns an `AddressUtxo`, a richer model than the `Utxo` returned for an address — it carries the stake address, payment and stake credentials, the reference script hash, and whether the output is a collateral return.

## Several Outputs at Once

`getUtxos` takes a list of transaction-hash and index pairs, which is the efficient way to resolve a transaction's inputs:

```swift
let utxos = try await yaci.client.getUtxos(
    body: .json([
        .init(txHash: firstHash, outputIndex: 0),
        .init(txHash: secondHash, outputIndex: 3),
    ])
).ok.body.json
```

Quantities here are `AddressUtxo.amounts`, which are `Amt` values with **integer** quantities — unlike the `Amount` values nested in a `Utxo`. <doc:Amounts> explains why.

## UTxOs Holding an Asset

```swift
// Every UTxO holding a unit, across all addresses
let holders = try await yaci.client.getAssetUtxos(
    path: .init(unit: unit),
    query: .init(page: 0, count: 100, order: .asc)
).ok.body.json

// Only those at one address
let mine = try await yaci.client.getUtxosForAsset(
    path: .init(address: address, asset: unit),
    query: .init(count: 100, page: 0)
).ok.body.json
```

## Related

- <doc:AddressEndpoints>
- <doc:AssetEndpoints>
- <doc:Amounts>
