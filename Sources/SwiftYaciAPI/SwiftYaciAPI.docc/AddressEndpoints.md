# Address and Account Endpoints

Balances, amounts, and transaction history for payment addresses and stake accounts.

## Address Balance

```swift
let balance = try await yaci.client.getAddressBalance(path: .init(address: address)).ok.body.json

print("As of block \(balance.blockNumber ?? 0), slot \(balance.slot ?? 0)")
for amount in balance.amounts ?? [] {
    print("  \(amount.unit ?? ""): \(amount.quantity ?? 0)")
}
```

`AddressBalanceDto.amounts` are `Amt` values, whose `quantity` is an `Int`.

## Address Amounts

A flatter view of the same information:

```swift
let amounts = try await yaci.client.getAddressAmounts(path: .init(address: address)).ok.body.json
let lovelace = amounts.first(where: { $0.unit == "lovelace" })?.quantity ?? 0
```

These are `AddressAmount` values, also with an integer `quantity` — see <doc:Amounts> for why this endpoint has its own model.

## Balance at a Point in Time

```swift
let past = try await yaci.client.getAddressBalanceAtTime(
    path: .init(address: address, unit: "lovelace", timeInSec: 1712345678)
).ok.body.json
```

## Address History

```swift
let transactions = try await yaci.client.getAddressTransactions(
    path: .init(address: address),
    query: .init(count: 50, page: 0, order: .desc)
).ok.body.json
```

## Stake Accounts

```swift
let account = try await yaci.client.getStakeAccountDetails(
    path: .init(stakeAddress: stakeAddress)
).ok.body.json

print("Controlled:   \(account.controlledAmount ?? 0)")
print("Withdrawable: \(account.withdrawableAmount ?? 0)")
print("Delegated to: \(account.poolId ?? "nothing")")
```

```swift
let balance = try await yaci.client.getStakeAddressBalance(
    path: .init(stakeAddress: stakeAddress)
).ok.body.json

let withdrawals = try await yaci.client.getWithdrawalsByAccount(
    path: .init(stakeAddress: stakeAddress),
    query: .init(page: 0, count: 50)
).ok.body.json
```

> Warning: For a stake address it has not indexed, Yaci Store answers `getStakeAddressBalance` with `200` and a body of literal `null` rather than `404`, and `getStakeAccountDetails` with `500`. Decoding a `null` body throws. See <doc:ErrorHandling>.

## Related

- <doc:UtxoEndpoints>
- <doc:StakeAndPoolEndpoints>
