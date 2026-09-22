# SwiftYaciAPI

A Swift library for accessing the [Yaci Store](https://github.com/bloxbean/yaci-store) REST API, providing type-safe access to Cardano blockchain data you index yourself.

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-blue.svg)](https://swift.org)
[![Build](https://github.com/Kingpin-Apps/swift-yaci-api/actions/workflows/swift.yml/badge.svg)](https://github.com/Kingpin-Apps/swift-yaci-api/actions/workflows/swift.yml)
[![Documentation](https://img.shields.io/badge/Documentation-DocC-blue.svg)](https://swiftpackageindex.com/Kingpin-Apps/swift-yaci-api/documentation)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

SwiftYaciAPI is a Swift Package Manager library that provides a type-safe, async/await interface to a Yaci Store instance. It lets iOS, macOS, watchOS, and tvOS applications query blocks, transactions, UTxOs, addresses, assets, accounts, scripts, epochs, and Conway-era governance data from an indexer you control.

The library is built with [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator): every request and response type is generated from the OpenAPI document Yaci Store publishes, so endpoints are checked at compile time.

## What is Yaci Store?

[Yaci Store](https://github.com/bloxbean/yaci-store) is a modular, self-hosted Cardano datastore from BloxBean. Each module indexes one slice of the chain into a relational database and exposes it over a REST API:

- **Self-hosted**: run it next to your own `cardano-node`, on any network, with no third-party rate limits
- **Modular**: enable only the modules you need (blocks, transactions, UTxOs, assets, governance, …)
- **Devnet friendly**: the default configuration targets `http://localhost:8080`, which is also what [Yaci DevKit](https://github.com/bloxbean/yaci-devkit) exposes
- **Open source**: Apache-2.0, actively maintained by the BloxBean team

## Features

- ✅ **Full endpoint coverage**: all 94 operations published by Yaci Store
- ✅ **Type-safe**: Swift models generated from the OpenAPI document
- ✅ **Async/await**: modern Swift concurrency throughout, `Sendable` client
- ✅ **Multi-platform**: iOS 14+, macOS 13+, watchOS 7+, tvOS 14+
- ✅ **Flexible configuration**: any base URL, defaulting to a local instance
- ✅ **Optional authentication**: bearer token from a literal or an environment variable
- ✅ **Testable**: inject your own `Client` and transport for unit tests

## Installation

### Swift Package Manager

Add SwiftYaciAPI to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/Kingpin-Apps/swift-yaci-api", from: "0.1.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version and add to your target

## Quick Start

### Basic Usage

```swift
import SwiftYaciAPI

// Defaults to a local Yaci Store instance at http://localhost:8080
let yaci = try Yaci()

// Latest block
let block = try await yaci.client.getLatestBlock().ok.body.json
print("Block \(block.number ?? 0) in epoch \(block.epoch ?? 0)")

// Latest epoch and protocol parameters
let epoch = try await yaci.client.getLatestEpoch().ok.body.json
let params = try await yaci.client.getLatestProtocolParams().ok.body.json
print("Epoch \(epoch.epoch ?? 0), min fee A \(params.minFeeA ?? 0)")
```

### Custom Base URL

```swift
// Point at a remote indexer
let yaci = try Yaci(basePath: "https://yaci.example.com:8080")

// Yaci DevKit's bundled store
let devkit = try Yaci(basePath: "http://localhost:8080")
```

`basePath` must be an absolute URL with a scheme and host; anything else throws ``YaciAPIError/invalidBasePath(_:)``.

### Authentication

Yaci Store is unauthenticated by default. If you put it behind a gateway that expects a bearer token:

```swift
// With an explicit token
let yaci = try Yaci(
    basePath: "https://yaci.example.com",
    apiKey: "your-token-here"
)

// Or read it from the environment
let yaci = try Yaci(
    basePath: "https://yaci.example.com",
    environmentVariable: "YACI_API_KEY"
)
```

The token is sent as `Authorization: Bearer <token>`. A value that already starts with `Bearer ` is passed through unchanged.

### Querying UTxOs

```swift
// All UTxOs at an address, newest first
let utxos = try await yaci.client.getUtxos1(
    path: .init(address: address),
    query: .init(count: 100, page: 0, order: .desc)
).ok.body.json

for utxo in utxos {
    // Quantities nested in a UTxO arrive as strings — see "Amounts" below.
    let lovelace = Int(utxo.amount?.first(where: { $0.unit == "lovelace" })?.quantity ?? "0") ?? 0
    print("\(utxo.txHash ?? "")#\(utxo.outputIndex ?? 0): \(lovelace) lovelace")
}

// Specific outputs by transaction hash and index
let specific = try await yaci.client.getUtxos(
    body: .json([.init(txHash: txHash, outputIndex: 0)])
).ok.body.json
```

### Address and Account Information

```swift
// Full balance, including native assets
let balance = try await yaci.client.getAddressBalance(
    path: .init(address: address)
).ok.body.json

// Stake account details
let account = try await yaci.client.getStakeAccountDetails(
    path: .init(stakeAddress: stakeAddress)
).ok.body.json
print("Delegated to \(account.poolId ?? "none")")
```

### Transaction Details

```swift
let tx = try await yaci.client.getTransaction(
    path: .init(txHash: txHash)
).ok.body.json

print("Fee: \(tx.fees ?? 0), inputs: \(tx.inputs?.count ?? 0), outputs: \(tx.outputs?.count ?? 0)")

let witnesses = try await yaci.client.getTransactionWitnesses(
    path: .init(txHash: txHash)
).ok.body.json
```

### Submitting and Evaluating Transactions

Both endpoints answer **`202 Accepted`** on success, not `200` — so match on
`.accepted`, not `.ok`:

```swift
// Submit a signed transaction. The body is raw CBOR bytes; the response is the
// transaction hash.
let submitted = try await yaci.client.submitTx1(
    body: .applicationCbor(HTTPBody(signedTxBytes))
)
let txHash = try submitted.accepted.body.json

// Evaluate execution units. Note the body is the transaction as *hex text*,
// under a CBOR content type — this is what the endpoint expects.
let evaluated = try await yaci.client.evaluateTx(
    query: .init(version: 6),
    body: .applicationCbor(HTTPBody(Data(txHex.utf8)))
)
let report = try evaluated.accepted.body.json   // the Ogmios payload
```

Evaluation needs Ogmios enabled on the instance (`ogmios_enabled=true` in Yaci
DevKit). The `version` query parameter selects the Ogmios response shape —
`version: 6` returns a JSON-RPC envelope whose `result` is a list of per-validator
budgets, while the default (5) returns a JSON-WSP envelope whose
`result.EvaluationResult` is a map keyed by `purpose:index`.

A rejected transaction arrives as `.undocumented(statusCode: 400, _)` with the
node's own decoder or ledger error in the body — keep it, it is what makes a
failed submission diagnosable:

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

### Governance (Conway Era)

```swift
let committee = try await yaci.client.getCommitteeMembers().ok.body.json
let constitution = try await yaci.client.getCurrentConstitution1().ok.body.json
let proposals = try await yaci.client.getGovActionProposalList(
    query: .init(page: 0, count: 10)
).ok.body.json
```

## Amounts

Yaci Store represents asset quantities two different ways, and the package models
each as it actually arrives:

```swift
// Nested in a UTxO — Amount.quantity is a String
let utxos = try await yaci.client.getUtxos1(path: .init(address: address)).ok.body.json
let nested = Int(utxos.first?.amount?.first?.quantity ?? "0") ?? 0

// Returned by /addresses/{address}/amounts — AddressAmount.quantity is an Int
let amounts = try await yaci.client.getAddressAmounts(path: .init(address: address)).ok.body.json
let direct = amounts.first?.quantity ?? 0
```

The store's OpenAPI document declares both as integers, but only one of them is.
The [Specification Fixes](https://swiftpackageindex.com/Kingpin-Apps/swift-yaci-api/documentation/swiftyaciapi/specificationfixes)
article has the detail;
the same applies to `BlockDto.output`, `BlockDto.fees` and
`BlockDto.op_cert_counter`, which are strings.

## Known Yaci Store Behaviours

- `getStakeAddressBalance` answers `200` with a body of literal `null` for a
  stake address the store has not indexed, rather than `404`. Decoding throws —
  catch it if you query arbitrary addresses.
- `getStakeAccountDetails` answers `500` for an unknown stake address, which
  arrives as `.undocumented(statusCode: 500, _)`.

## Error Handling

Client construction throws ``YaciAPIError``:

```swift
do {
    let yaci = try Yaci(basePath: "not a url", environmentVariable: "YACI_API_KEY")
} catch let error as YaciAPIError {
    switch error {
    case .invalidBasePath: print("Bad base path: \(error)")
    case .missingAPIKey:   print("Missing API key: \(error)")
    case .valueError:      print("Bad value: \(error)")
    }
}
```

Requests surface failures through the generated output enum. Accessing `.ok` throws when the server answered with anything else, so match on the output when you want to handle those cases yourself:

```swift
let output = try await yaci.client.getBlockByNumber(path: .init(numberOrHash: "99999999"))

switch output {
case .ok(let response):
    let block = try response.body.json
    print(block.hash ?? "")
case .undocumented(let statusCode, _):
    print("Yaci Store returned \(statusCode)")
}
```

## Available Endpoints

All endpoints are reachable through `yaci.client`. Highlights by module:

### Blocks
`getLatestBlock`, `getBlockByNumber`, `getBlocks`, `getBlocksByEpoch`, `getBlocksBySlotLeaderEpoch`, `getTransactions1`

### Epochs
`getLatestEpoch`, `getEpochByNumber`, `getEpochs`, `getLatestProtocolParams`, `getProtocolParams`

### Transactions
`getTransaction`, `getTransactions`, `getTransactionWitnesses`, `getTransactionInputsOutputs`, `getTxRedeemers`, `getTxContractDetails`, `getMetadataByTxHash`, `getMetadataCborByTxHash`, `getMetadataByLabel`, `getWithdrawals`, `submitTx1`, `evaluateTx`, `evaluateTx1`

### UTxOs
`getUtxos`, `getUtxo`, `getUtxos1`, `getUtxosForAsset`

### Addresses and Accounts
`getAddressBalance`, `getAddressAmounts`, `getAddressTransactions`, `getAddressBalanceAtTime`, `getStakeAccountDetails`, `getStakeAddressBalance`, `getStakeAddressBalanceAtTime`, `getWithdrawalsByAccount`

### Assets
`getSupplyByUnit`, `getSupplyByPolicy`, `getSupplyByFingerprint`, `getAssetUtxos`, `getAssetTransactions`, `getAddressesByAsset`, `getAssetTxsByUnit`, `getAssetTxsByPolicyId`, `getAssetTxsByFingerprint`

### Stake and Pools
`getStakeRegistrations`, `getStakeDeRegistrations`, `getStakeDelegations`, `getRegisteredStakeAddresses`, `getPoolRegistrations`, `getPoolDetails`, `getRetirements`, `getRetiringPoolIds`

### Scripts
`getScriptByHash`, `getScriptJsonByHash`, `getScriptCborByHash`, `getScriptDetailsByHash`, `getDatumJsonByHash`, `getDatumCborByHash`

### Governance
`getGovActionProposalList`, `getGovActionProposalByTx`, `getVotingProcedureList`, `getVotingProcedureByTx`, `getDRepRegistrations`, `getDRepUpdates`, `getDRepDeRegistrations`, `getDelegations`, `getDelegationsOfDRep`, `getDelegationsByAddress`, `getCommitteeMembers`, `getCommitteeRegistrations`, `getCommitteeDeRegistrations`, `getCurrentConstitution1`, `getDRepStakeDistr`, `getMIRSummaries`, `getProtocolParamProposals`

## Testing

Inject a `Client` backed by your own `ClientTransport` to test without a running indexer:

```swift
import Testing
import OpenAPIRuntime
import HTTPTypes
@testable import SwiftYaciAPI

struct StubTransport: ClientTransport {
    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let json = #"{"number": 1234567, "epoch": 152}"#
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

The package's own suite (`Tests/SwiftYaciAPITests`) follows this pattern, with JSON fixtures keyed by operation ID.

### Integration tests

`Tests/SwiftYaciAPITests/IntegrationTests.swift` runs the client against a real
store — a [Yaci DevKit](https://github.com/bloxbean/yaci-devkit) node, or any instance you point it at.
The suite is skipped unless `YACI_BASE_URL` is set, so `swift test` stays
hermetic by default:

```bash
YACI_BASE_URL=http://localhost:8080 swift test
```

Tests that need indexed data (transactions, addresses) discover it from the
store rather than hard-coding hashes, so they work against a fresh devkit or a
synced node.

The query endpoints are read-only. Submission and evaluation are covered too,
and the round-trip test needs a signed transaction the node has not seen yet —
submitting spends its input, so a fresh one is needed per run.
`scripts/devkit-signed-tx.sh` builds one against a running DevKit:

```bash
export YACI_TEST_TX_HEX="$(./scripts/devkit-signed-tx.sh)"
YACI_BASE_URL=http://localhost:8080 swift test
```

That test evaluates the transaction (which consumes nothing), submits it, and
then polls the store until the transaction is indexed — an end-to-end check that
the bytes really reached the chain. Without `YACI_TEST_TX_HEX` it is skipped and
the rejection tests still run, since those need only a running store.

The script signs with the devnet's own genesis UTxO key and pays back to the
same address, so it only moves value between the devnet's accounts. **Point it
at a local devnet only.**

## Regenerating the API

The generated code is produced at build time by the OpenAPI generator plugin from `Sources/SwiftYaciAPI/openapi.yaml`. To refresh it against a running instance:

```bash
curl -s http://localhost:8080/v3/api-docs -o /tmp/api-docs.json
# convert JSON → YAML, then write it to Sources/SwiftYaciAPI/openapi.yaml and openapi.yml
python3 scripts/fix-openapi.py
swift build
```

`scripts/fix-openapi.py` re-applies the local corrections the published document needs. Its module docstring lists them, and the
[Specification Fixes](https://swiftpackageindex.com/Kingpin-Apps/swift-yaci-api/documentation/swiftyaciapi/specificationfixes)
article explains what each one changes and why.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

### Development Setup

```bash
# Clone the repository
git clone https://github.com/Kingpin-Apps/swift-yaci-api
cd swift-yaci-api

# Build the project
swift build

# Run tests
swift test
```

A [Justfile](Justfile) wraps the common tasks (`just build`, `just test`, `just release`, `just bump`).

## Documentation

Full API documentation is published on the
[Swift Package Index](https://swiftpackageindex.com/Kingpin-Apps/swift-yaci-api/documentation),
generated from the DocC catalog in `Sources/SwiftYaciAPI/SwiftYaciAPI.docc`.

Articles worth reading before you build against this package:

- **Getting Started**, **Installation**, **Client Configuration** — connecting and authenticating
- **Amounts** — quantities are `String` in some models and `Int` in others; this explains which and why
- **Transaction Endpoints** — submission and evaluation, including the `202` response
- **Error Handling** — non-success responses and two Yaci Store quirks to guard against
- **Specification Fixes** — why the bundled OpenAPI document differs from the published one

Build the catalog locally with:

```bash
xcodebuild docbuild -scheme SwiftYaciAPI \
  -destination 'generic/platform=macOS' \
  -derivedDataPath .docbuild \
  -skipPackagePluginValidation
```

### Yaci Store
- [Yaci Store](https://github.com/bloxbean/yaci-store)
- [Yaci Store Documentation](https://store.yaci.xyz/)
- [Yaci DevKit](https://github.com/bloxbean/yaci-devkit)

### Cardano Resources
- [Cardano Developer Portal](https://developers.cardano.org/)
- [Cardano Foundation](https://cardanofoundation.org/)

### Swift OpenAPI
- [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator)
- [OpenAPI Runtime](https://github.com/apple/swift-openapi-runtime)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [BloxBean](https://github.com/bloxbean) for Yaci Store and Yaci DevKit
- [Cardano Community](https://cardano.org/) for the ecosystem
- [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator) for the code generation tooling

## Support

- **Issues**: [GitHub Issues](https://github.com/Kingpin-Apps/swift-yaci-api/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Kingpin-Apps/swift-yaci-api/discussions)
