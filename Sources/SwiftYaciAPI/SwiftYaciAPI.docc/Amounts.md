# Amounts

How Yaci Store represents quantities, and why it is not uniform.

## Overview

Cardano quantities can exceed what a 64-bit integer holds safely, so Yaci Store serialises many of them as JSON strings. It does this inconsistently — the same logical value is a number in one response and a string in another — and its published OpenAPI document declares several of them as integers regardless.

SwiftYaciAPI models each field the way it actually arrives, verified against a live instance. That means you cannot assume a quantity is an `Int`, but you can trust the type the model gives you.

## Which Is Which

| Model | Field | Swift type |
| --- | --- | --- |
| `Amount` (nested in `Utxo`, `TxUtxo`) | `quantity` | `String` |
| `AddressAmount` (from `getAddressAmounts`) | `quantity` | `Int` |
| `Amt` (nested in `AddressUtxo`, `AddressBalanceDto`) | `quantity` | `Int` |
| `AddressAssetBalanceDto` | `quantity` | `String` |
| `BlockDto` | `output`, `fees`, `opCertCounter` | `String` |
| `BlockSummary` | `output`, `fees` | `Int` |
| `EpochDto` | `output`, `fees`, `activeStake` | `String` |
| `Epoch` | `totalOutput`, `totalFees` | `Int` |
| `TransactionDetails` | `fees`, `totalOutput` | `Int` |
| `ProtocolParamsDto` | `keyDeposit`, `poolDeposit`, `minPoolCost`, execution-unit limits | `String` |
| `ProtocolParamsDto` | `govActionDeposit`, `drepDeposit` | `Int` |

The clearest trap is the pair of amount models. Two unrelated Java classes are published under the single schema name `Amount`, and they disagree: nested in a UTxO the quantity is a string, while `/addresses/{address}/amounts` returns a number. SwiftYaciAPI splits them, so `getAddressAmounts` returns `AddressAmount` rather than `Amount`.

```swift
// Nested in a UTxO — a String
let utxos = try await yaci.client.getUtxos1(path: .init(address: address)).ok.body.json
let nested = Int(utxos.first?.amount?.first?.quantity ?? "0") ?? 0

// From getAddressAmounts — an Int
let amounts = try await yaci.client.getAddressAmounts(path: .init(address: address)).ok.body.json
let direct = amounts.first?.quantity ?? 0
```

## Working With String Quantities

Convert once, at the edge, rather than scattering conversions:

```swift
extension Components.Schemas.Amount {
    /// The quantity as an integer, or nil when absent or unparseable.
    var value: Int? {
        quantity.flatMap(Int.init)
    }
}

let lovelace = utxo.amount?
    .first { $0.unit == "lovelace" }?
    .value ?? 0
```

For values that may exceed `Int.max`, keep the string and hand it to a big-integer type rather than converting.

## Units

An asset is identified by a *unit*: the policy ID concatenated with the hex-encoded asset name. Lovelace uses the literal unit `"lovelace"`.

```swift
let isAda = amount.unit == "lovelace"
let policyId = amount.policyId        // also provided separately
let assetName = amount.assetName      // decoded where Yaci Store could decode it
```

## Related

- <doc:SpecificationFixes> — why the bundled document differs from the published one
- <doc:UtxoEndpoints>
