## 0.1.0 (2026-09-21)

### Feat

- add type-safe Yaci Store client generated from the published OpenAPI document
- add `Yaci` client wrapper with base URL resolution, optional bearer
  authentication, and injectable `Client` for testing
- add `YaciAPIError` for client configuration failures
- add DocC catalog and Swift Package Index documentation configuration

### Fix

- declare response bodies as `application/json` so all 94 operations generate
  typed models instead of untyped `HTTPBody`
- declare the `202 Accepted` that `/tx/submit` and `/utils/txs/evaluate` return
  on success, so successful submission and evaluation no longer decode as
  `.undocumented`
- retype `BlockDto.output`, `BlockDto.fees`, `BlockDto.op_cert_counter` and
  `Amount.quantity` as strings, matching what the server serialises
- split `AddressAmount` out of `Amount`, which the upstream document publishes
  for two incompatible payloads
- reject a `basePath` that is not an absolute URL instead of building a relative
  one that fails at request time
- remove a redundant `HTTPField.Name.authorization` that made the symbol
  ambiguous for anything importing both this package and `HTTPTypes`
