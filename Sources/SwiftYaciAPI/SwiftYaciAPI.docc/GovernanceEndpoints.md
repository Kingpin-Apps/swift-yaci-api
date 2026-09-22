# Governance Endpoints

Conway-era proposals, votes, DReps, and the constitutional committee.

## Proposals

```swift
let proposals = try await yaci.client.getGovActionProposalList(
    query: .init(page: 0, count: 25)
).ok.body.json

for proposal in proposals {
    print("\(proposal.txHash ?? "")#\(proposal.index ?? 0)")
    print("  Type:    \(proposal._type?.rawValue ?? "unknown")")
    print("  Deposit: \(proposal.deposit ?? 0)")
    print("  Anchor:  \(proposal.anchorUrl ?? "none")")
}
```

Proposals can also be fetched by the transaction that created them, by return address, or by type:

```swift
let byTransaction = try await yaci.client.getGovActionProposalByTx(
    path: .init(txHash: txHash)
).ok.body.json

let byReturnAddress = try await yaci.client.getGovActionProposalByReturnAddress(
    path: .init(address: stakeAddress),
    query: .init(page: 0, count: 25)
).ok.body.json

let byType = try await yaci.client.getGovActionProposalByGovActionType(
    path: .init(govActionType: .infoAction),
    query: .init(page: 0, count: 25)
).ok.body.json

let mostRecent = try await yaci.client.getMostRecentGovActionProposalByGovActionType(
    path: .init(govActionType: .infoAction)
).ok.body.json
```

`govActionType` is a generated enum, so the cases are fixed at compile time rather than free strings.

## Votes

```swift
let votes = try await yaci.client.getVotingProcedureList(
    query: .init(page: 0, count: 50)
).ok.body.json

for vote in votes {
    print("\(vote.voterType?.rawValue ?? "") \(vote.voterHash ?? "") voted \(vote.vote?.rawValue ?? "")")
}
```

Votes cast in a transaction, by identifier, or on a specific proposal:

```swift
let byTransaction = try await yaci.client.getVotingProcedureByTx(path: .init(txHash: txHash)).ok.body.json
let byId = try await yaci.client.getVotingProcedureById(path: .init(id: voteId)).ok.body.json

let onProposal = try await yaci.client.getVotingProceduresForGovActionProposal(
    path: .init(txHash: proposalTxHash, indexInTx: 0),
    query: .init(page: 0, count: 50)
).ok.body.json
```

## DReps

```swift
let registrations = try await yaci.client.getDRepRegistrations(query: .init(page: 0, count: 50)).ok.body.json
let updates = try await yaci.client.getDRepUpdates(query: .init(page: 0, count: 50)).ok.body.json
let retirements = try await yaci.client.getDRepDeRegistrations(query: .init(page: 0, count: 50)).ok.body.json

// Live stake behind a DRep, queried from the node
let stake = try await yaci.client.getDRepStakeDistr(path: .init(dRepHash: drepHash)).ok.body.json
```

## Vote Delegation

```swift
let all = try await yaci.client.getDelegations(query: .init(page: 0, count: 50)).ok.body.json

let toDRep = try await yaci.client.getDelegationsOfDRep(
    path: .init(dRepId: drepId),
    query: .init(page: 0, count: 50)
).ok.body.json

let forAddress = try await yaci.client.getDelegationsByAddress(
    path: .init(address: stakeAddress),
    query: .init(page: 0, count: 50)
).ok.body.json
```

## Committee and Constitution

```swift
let committee = try await yaci.client.getCommitteeMembers().ok.body.json
print("Threshold: \(committee.thresholdNumerator ?? 0)/\(committee.thresholdDenominator ?? 0)")
for member in committee.members ?? [] {
    print("  \(member.hash ?? "") expires in epoch \(member.expiredEpoch ?? 0)")
}

let constitution = try await yaci.client.getCurrentConstitution1().ok.body.json
print("Anchor: \(constitution.anchorUrl ?? "")")

let registrations = try await yaci.client.getCommitteeRegistrations(query: .init(page: 0, count: 50)).ok.body.json
let resignations = try await yaci.client.getCommitteeDeRegistrations(query: .init(page: 0, count: 50)).ok.body.json
```

### Indexed versus live

Some governance data is served twice: once from the index, and once queried live from the node.

| Indexed | Live from the node |
| --- | --- |
| `getCurrentConstitution1` | `getCurrentConstitution` |
| `getCommitteeMembers` | `getCommitteeInfo` |

The live variants need a node connection configured on the instance and reflect the node's current view; the indexed ones reflect what Yaci Store has processed. On an instance without that connection, the live variants fail while the indexed ones keep working.

## Related

- <doc:StakeAndPoolEndpoints>
