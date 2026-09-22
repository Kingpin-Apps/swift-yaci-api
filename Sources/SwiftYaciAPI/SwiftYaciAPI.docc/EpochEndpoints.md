# Epoch Endpoints

Query epochs and the protocol parameters in force for them.

## Latest Epoch

```swift
let epoch = try await yaci.client.getLatestEpoch().ok.body.json

print("Epoch:        \(epoch.epoch ?? 0)")
print("Blocks:       \(epoch.blockCount ?? 0)")
print("Transactions: \(epoch.txCount ?? 0)")
print("Output:       \(epoch.output ?? "0") lovelace")
print("Fees:         \(epoch.fees ?? "0") lovelace")
```

`EpochDto.output`, `fees` and `activeStake` are `String` values — they hold quantities too large to assume fit in an `Int`.

## A Specific Epoch

`getEpochByNumber` returns an `Epoch`, a different model from the `EpochDto` that `getLatestEpoch` returns, with its totals as integers:

```swift
let epoch = try await yaci.client.getEpochByNumber(path: .init(number: 500)).ok.body.json

print("Blocks:  \(epoch.blockCount ?? 0)")
print("Output:  \(epoch.totalOutput ?? 0)")
print("Max slot: \(epoch.maxSlot ?? 0)")
```

## Listing Epochs

```swift
let page = try await yaci.client.getEpochs(query: .init(page: 0, count: 10)).ok.body.json

for epoch in page.epochs ?? [] {
    print("Epoch \(epoch.number ?? 0): \(epoch.transactionCount ?? 0) transactions")
}
```

## Protocol Parameters

```swift
// Current parameters
let current = try await yaci.client.getLatestProtocolParams().ok.body.json

print("Min fee A:    \(current.minFeeA ?? 0)")
print("Min fee B:    \(current.minFeeB ?? 0)")
print("Max tx size:  \(current.maxTxSize ?? 0)")
print("Key deposit:  \(current.keyDeposit ?? "0")")
print("Protocol:     \(current.protocolMajorVer ?? 0).\(current.protocolMinorVer ?? 0)")

// Parameters as they were for a past epoch
let historic = try await yaci.client.getProtocolParams(path: .init(number: 500)).ok.body.json
```

`ProtocolParamsDto` mixes representations, following the ledger: deposits and execution-unit limits are `String`, while counts and sizes are integers. `costModels` is a dictionary of cost-model name to operation costs.

## Related

- <doc:BlockEndpoints>
- <doc:Amounts>
