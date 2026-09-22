# Getting Started

Connect to a Yaci Store instance and make your first queries.

## Overview

SwiftYaciAPI talks to a Yaci Store instance you run. The quickest way to get one is [Yaci DevKit](https://github.com/bloxbean/yaci-devkit), which starts a local Cardano devnet with Yaci Store already attached on port `8080`.

Against a public network, run [Yaci Store](https://github.com/bloxbean/yaci-store) alongside your own `cardano-node` and point the client at it.

## Creating a Client

``Yaci`` defaults to `http://localhost:8080`, which is where both Yaci Store and Yaci DevKit listen:

```swift
import SwiftYaciAPI

let yaci = try Yaci()
```

Pass a `basePath` to reach anything else. It must be an absolute URL, with a scheme and a host:

```swift
let remote = try Yaci(basePath: "https://yaci.example.com:8080")
```

See <doc:ClientConfiguration> for authentication and for injecting your own transport.

## Making Requests

Every operation lives on ``Yaci/client``, the generated OpenAPI client. Each one returns an output enum rather than throwing on a non-success status, so a missing resource is a value you can match on rather than an error you have to catch:

```swift
// The response carries a generated model
let block = try await yaci.client.getLatestBlock().ok.body.json
print(block.hash ?? "")

// Or handle the non-success case explicitly
switch try await yaci.client.getBlockByNumber(path: .init(numberOrHash: "1234567")) {
case .ok(let response):
    print(try response.body.json.hash ?? "")
case .undocumented(let statusCode, _):
    print("Yaci Store returned \(statusCode)")
}
```

Accessing `.ok` on a response that was not a `200` throws, which is convenient when any non-success is simply an error for your purposes. <doc:ErrorHandling> covers both styles.

## Paging

List endpoints take `page` and `count` query parameters. `page` is zero-based and `count` is capped at 100:

```swift
let page = try await yaci.client.getBlocks(query: .init(page: 0, count: 50)).ok.body.json
print("\(page.blocks?.count ?? 0) of \(page.total ?? 0) blocks")
```

Some endpoints also take an `order` of `.asc` or `.desc`:

```swift
let utxos = try await yaci.client.getUtxos1(
    path: .init(address: address),
    query: .init(count: 100, page: 0, order: .desc)
).ok.body.json
```

## Next Steps

- <doc:ClientConfiguration> — base URLs, authentication, custom transports
- <doc:Amounts> — how quantities are represented, which is not uniform
- <doc:TransactionEndpoints> — submitting and evaluating transactions
