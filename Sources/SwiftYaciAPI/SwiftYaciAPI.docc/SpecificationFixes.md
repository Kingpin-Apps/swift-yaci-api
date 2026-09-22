# Specification Fixes

Why the bundled OpenAPI document differs from the one Yaci Store publishes.

## Overview

`Sources/SwiftYaciAPI/openapi.yaml` is not hand-written. It is the document Yaci Store serves at `/v3/api-docs`, produced by Springdoc from the Spring controllers — and in four places it does not describe what the server actually does. Generating against it unmodified produces a client that either throws away every schema or fails to decode real responses.

`scripts/fix-openapi.py` applies the corrections and is idempotent, so it can be re-run after every refresh of the document. Each fix was verified against a running instance, and the script's module docstring records the reasoning alongside the code that applies it.

## The Four Fixes

### 1. `*/*` response media types

None of the controllers declare `produces`, so Springdoc labels every response body `*/*`. `swift-openapi-generator` cannot attach a schema to a wildcard media type, so it discards the schema and emits an untyped `HTTPBody` — which would leave 92 of the 94 operations returning raw bytes.

Responses carrying a concrete schema are rewritten to `application/json`, which is what the server really sends.

### 2. Integers that arrive as strings

Springdoc types some fields from their Java `BigInteger`, but Jackson serialises them with a string serializer. The document says `integer`; the wire says `"0"`.

`BlockDto.output`, `BlockDto.fees`, `BlockDto.op_cert_counter` and `Amount.quantity` are retyped to `string`. The list is deliberately narrow — the other `BigInteger`-shaped fields were checked against a live instance and really are numbers.

### 3. `202 Accepted` on submission and evaluation

`/tx/submit` and `/utils/txs/evaluate` answer `202` when the node accepts the work, but only `200` is documented — so every *successful* call decoded as `.undocumented`. Both statuses are now declared, with the body each returns: the transaction hash for submission, the Ogmios payload for evaluation.

### 4. Two DTOs published as `Amount`

Springdoc publishes two unrelated Java classes under one schema name. Nested in a UTxO the quantity is a string; returned by `/addresses/{address}/amounts` it is a number. A separate `AddressAmount` schema is added for that endpoint. See <doc:Amounts>.

## Refreshing the Document

```bash
curl -s http://localhost:8080/v3/api-docs -o api-docs.json
# convert JSON to YAML, write to Sources/SwiftYaciAPI/openapi.yaml and openapi.yml
python3 scripts/fix-openapi.py
swift build
swift test
```

Run the integration suite against a live instance afterwards. It is what catches a field whose representation changed, since a hermetic test only proves the client agrees with its own fixtures.

## What Is Not Changed

Several operation IDs carry a `_1` suffix — `getUtxos_1`, `submitTx_1`, `getLatestEpoch_1`, `getCurrentConstitution_1` and others — which the generator turns into `getUtxos1`, `submitTx1`, and so on. Springdoc adds the suffix when two controller methods share a name. The names are awkward, but they are stable, and renaming them would break every caller the next time the document is refreshed.

## Related

- <doc:Amounts>
- <doc:TransactionEndpoints>
