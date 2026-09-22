# Transaction Endpoints

Query transactions, and submit and evaluate new ones.

## Transaction Details

```swift
let tx = try await yaci.client.getTransaction(path: .init(txHash: txHash)).ok.body.json

print("Block:   \(tx.blockHeight ?? 0)")
print("Fee:     \(tx.fees ?? 0) lovelace")
print("Inputs:  \(tx.inputs?.count ?? 0)")
print("Outputs: \(tx.outputs?.count ?? 0)")
print("Valid:   \(tx.invalid != true)")
```

Related detail is spread across several endpoints:

```swift
let witnesses = try await yaci.client.getTransactionWitnesses(path: .init(txHash: txHash)).ok.body.json
let utxos = try await yaci.client.getTransactionInputsOutputs(path: .init(txHash: txHash)).ok.body.json
let redeemers = try await yaci.client.getTxRedeemers(path: .init(txHash: txHash)).ok.body.json
let contracts = try await yaci.client.getTxContractDetails(path: .init(txHash: txHash)).ok.body.json
let withdrawals = try await yaci.client.getWithdrawalsByTransaction(path: .init(txHash: txHash)).ok.body.json
```

## Metadata

```swift
// Metadata attached to one transaction, as JSON or as CBOR
let metadata = try await yaci.client.getMetadataByTxHash(path: .init(txHash: txHash)).ok.body.json
let cbor = try await yaci.client.getMetadataCborByTxHash(path: .init(txHash: txHash)).ok.body.json

// Everything carrying a given label, such as CIP-20 messages (674)
let labelled = try await yaci.client.getMetadataByLabel(
    path: .init(label: "674"),
    query: .init(page: 0, count: 50)
).ok.body.json
```

## Listing Transactions

```swift
let page = try await yaci.client.getTransactions(query: .init(page: 0, count: 25)).ok.body.json

for summary in page.transactionSummaries ?? [] {
    print("\(summary.txHash ?? ""): \(summary.totalOutput ?? 0) lovelace, fee \(summary.fee ?? 0)")
}
```

## Submitting a Transaction

> Important: Submission answers **`202 Accepted`** on success, not `200`. Match on `.accepted`; `.ok` will throw.

The endpoint takes raw CBOR bytes and returns the transaction hash:

```swift
let submitted = try await yaci.client.submitTx1(
    body: .applicationCbor(HTTPBody(signedTransactionBytes))
)
let txHash = try submitted.accepted.body.json
```

A transaction the node rejects arrives as `.undocumented`, carrying the node's own error — keep it, because it is what makes a failure diagnosable:

```swift
switch try await yaci.client.submitTx1(body: .applicationCbor(HTTPBody(cbor))) {
case .accepted(let response):
    return try response.body.json
case .ok(let response):
    return try response.body.json
case .undocumented(let statusCode, let payload):
    let detail = try await String(collecting: payload.body ?? .init(""), upTo: 8192)
    throw MyError.submissionFailed(statusCode: statusCode, detail: detail)
}
```

## Evaluating a Transaction

Evaluation reports the execution units a transaction's scripts consume. It needs Ogmios enabled on the instance — `ogmios_enabled=true` in Yaci DevKit.

> Important: The body is the transaction as **hex text**, not raw bytes, even though the content type is `application/cbor`. Evaluation also answers `202`.

```swift
let evaluated = try await yaci.client.evaluateTx(
    query: .init(version: 6),
    body: .applicationCbor(HTTPBody(Data(transactionHex.utf8)))
)
let payload = try evaluated.accepted.body.json
```

The `version` parameter selects the Ogmios response shape, and the two differ enough to matter:

- **`version: 6`** — a JSON-RPC envelope whose `result` is a list of entries, each with a `validator` (`purpose` and `index`) and a `budget` (`memory` and `cpu`).
- **the default, 5** — a JSON-WSP envelope whose `result.EvaluationResult` is a map keyed by `"purpose:index"`, with `memory` and `steps`.

```swift
// Ogmios v6
if let result = payload.value["result"] as? [[String: Any]] {
    for entry in result {
        let validator = entry["validator"] as? [String: Any]
        let budget = entry["budget"] as? [String: Any]
        print("\(validator?["purpose"] ?? ""):\(validator?["index"] ?? ""))"
            + " mem \(budget?["memory"] ?? 0), cpu \(budget?["cpu"] ?? 0)")
    }
}
```

`evaluateTx1` is the same operation with a Blockfrost-compatible request body that also accepts additional UTxOs. Yaci Store does not currently use them.

## Related

- <doc:UtxoEndpoints>
- <doc:ErrorHandling>
