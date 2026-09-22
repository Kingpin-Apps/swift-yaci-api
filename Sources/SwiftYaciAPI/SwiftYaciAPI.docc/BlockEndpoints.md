# Block Endpoints

Query blocks by height, hash, epoch, or slot leader.

## Latest Block

```swift
let block = try await yaci.client.getLatestBlock().ok.body.json

print("Height:   \(block.number ?? 0)")
print("Hash:     \(block.hash ?? "")")
print("Slot:     \(block.slot ?? 0)")
print("Epoch:    \(block.epoch ?? 0)")
print("Txs:      \(block.txCount ?? 0)")
```

> Note: `BlockDto.output`, `BlockDto.fees` and `BlockDto.opCertCounter` are `String`, not integers — Yaci Store serialises them as JSON strings. See <doc:Amounts>.

## A Specific Block

`getBlockByNumber` accepts either a block number or a block hash in the same parameter:

```swift
let byNumber = try await yaci.client.getBlockByNumber(
    path: .init(numberOrHash: "1234567")
).ok.body.json

let byHash = try await yaci.client.getBlockByNumber(
    path: .init(numberOrHash: blockHash)
).ok.body.json
```

## Listing Blocks

The list endpoints return a `BlocksPage`, whose `blocks` are `BlockSummary` values — a smaller model than the `BlockDto` returned for a single block:

```swift
let page = try await yaci.client.getBlocks(query: .init(page: 0, count: 25)).ok.body.json

print("\(page.total ?? 0) blocks across \(page.totalPages ?? 0) pages")
for summary in page.blocks ?? [] {
    print("\(summary.number ?? 0): \(summary.txCount ?? 0) txs, \(summary.size ?? 0) bytes")
}
```

Blocks can also be listed by epoch, or by the pool that minted them:

```swift
let inEpoch = try await yaci.client.getBlocksByEpoch(
    path: .init(epoch: 500),
    query: .init(page: 0, count: 50)
).ok.body.json

let byPool = try await yaci.client.getBlocksBySlotLeaderEpoch(
    path: .init(poolId: poolId),
    query: .init(epoch: 500)
).ok.body.json
```

## Transactions in a Block

```swift
let transactions = try await yaci.client.getTransactions1(
    path: .init(block: "1234567")
).ok.body.json
```

## Related

- <doc:EpochEndpoints>
- <doc:TransactionEndpoints>
