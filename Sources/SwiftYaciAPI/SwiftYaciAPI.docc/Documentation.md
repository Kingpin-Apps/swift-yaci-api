# ``SwiftYaciAPI``

A type-safe Swift client for the Yaci Store REST API, providing access to Cardano blockchain data from an indexer you run yourself.

## Overview

SwiftYaciAPI is a Swift Package Manager library that provides an idiomatic async/await interface to [Yaci Store](https://github.com/bloxbean/yaci-store). Built with Apple's [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator), it offers compile-time type safety, structured concurrency, and generated models for every Yaci Store endpoint.

Yaci Store is a modular datastore for Cardano that indexes blocks, transactions, UTxOs, addresses, assets, accounts, scripts, epochs, and Conway-era governance into a relational database, and serves them over REST. Because you run it yourself — next to your own node, or as part of [Yaci DevKit](https://github.com/bloxbean/yaci-devkit) — there are no third-party rate limits and no API key by default.

### Key Features

- **Type safety**: generated Swift models for all 94 operations
- **Async/await**: modern Swift concurrency throughout, with a `Sendable` client
- **Self-hosted**: points at `http://localhost:8080` out of the box
- **Optional authentication**: bearer token from a literal or an environment variable
- **Testable**: inject your own `Client` and transport, with no network involved
- **Corrected specification**: the bundled OpenAPI document is patched to match what a real instance sends — see <doc:SpecificationFixes>

### Quick Example

```swift
import SwiftYaciAPI

// Connect to a local Yaci Store instance
let yaci = try Yaci()

// Query the latest block
let block = try await yaci.client.getLatestBlock().ok.body.json
print("Block \(block.number ?? 0) in epoch \(block.epoch ?? 0)")
```

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Installation>
- <doc:ClientConfiguration>

### Querying the Chain

- <doc:BlockEndpoints>
- <doc:EpochEndpoints>
- <doc:TransactionEndpoints>
- <doc:UtxoEndpoints>
- <doc:AddressEndpoints>
- <doc:AssetEndpoints>
- <doc:StakeAndPoolEndpoints>
- <doc:ScriptEndpoints>
- <doc:GovernanceEndpoints>

### Working With Responses

- <doc:Amounts>
- <doc:ErrorHandling>

### Development

- <doc:Testing>
- <doc:SpecificationFixes>

### Client & Configuration

- ``Yaci``
- ``YaciAPIError``
