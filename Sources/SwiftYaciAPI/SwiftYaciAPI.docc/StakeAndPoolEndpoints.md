# Stake and Pool Endpoints

Stake registrations, delegations, and stake pool lifecycle.

## Stake Registrations and Delegations

```swift
let registrations = try await yaci.client.getStakeRegistrations(
    query: .init(page: 0, count: 50)
).ok.body.json

let deregistrations = try await yaci.client.getStakeDeRegistrations(
    query: .init(page: 0, count: 50)
).ok.body.json

let delegations = try await yaci.client.getStakeDelegations(
    query: .init(page: 0, count: 50)
).ok.body.json
```

Stake addresses registered as of a given epoch:

```swift
let registered = try await yaci.client.getRegisteredStakeAddresses(
    path: .init(epoch: 500),
    query: .init(page: 0, count: 100)
).ok.body.json
```

## Stake Pools

```swift
let registrations = try await yaci.client.getPoolRegistrations(
    query: .init(page: 0, count: 50)
).ok.body.json

for pool in registrations {
    print("\(pool.poolId ?? ""): pledge \(pool.pledge ?? 0), cost \(pool.cost ?? 0)")
}
```

A pool's state in a specific epoch:

```swift
let details = try await yaci.client.getPoolDetails(
    path: .init(poolId: poolId, epoch: 500)
).ok.body.json
```

## Retirements

```swift
let retirements = try await yaci.client.getRetirements(
    query: .init(page: 0, count: 50)
).ok.body.json

// Pools retiring at the end of a given epoch
let retiring = try await yaci.client.getRetiringPoolIds(path: .init(epoch: 500)).ok.body.json
```

## Rewards and Proposals

```swift
// Move instantaneous rewards
let summaries = try await yaci.client.getMIRSummaries(query: .init(page: 0, count: 50)).ok.body.json
let byTransaction = try await yaci.client.getMIRByTxHash(path: .init(txHash: txHash)).ok.body.json

// Protocol parameter update proposals
let proposals = try await yaci.client.getProtocolParamProposals(
    query: .init(page: 0, count: 50)
).ok.body.json
```

## Related

- <doc:AddressEndpoints>
- <doc:GovernanceEndpoints>
