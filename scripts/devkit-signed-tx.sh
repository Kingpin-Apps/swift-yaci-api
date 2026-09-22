#!/usr/bin/env bash
#
# Build and sign a throwaway self-payment transaction on a running Yaci DevKit,
# and print its CBOR hex.
#
# The integration tests need a transaction the node has not seen yet, because
# submitting spends its input. Run this each time to get a fresh one:
#
#   export YACI_TEST_TX_HEX="$(./scripts/devkit-signed-tx.sh)"
#   YACI_BASE_URL=http://localhost:8080 swift test
#
# It signs with the devnet's own genesis UTxO key and pays back to the same
# address, so it only moves value between the devnet's own accounts. Never point
# this at anything but a local devnet.
#
# Environment:
#   YACI_DEVKIT_CONTAINER  devkit container name (default: auto-detected)
#   YACI_TESTNET_MAGIC     network magic (default: 42)
set -euo pipefail

CONTAINER="${YACI_DEVKIT_CONTAINER:-$(docker ps --format '{{.Names}}|{{.Image}}' | grep bloxbean/yaci-cli | cut -d"|" -f1 | head -1)}"
MAGIC="${YACI_TESTNET_MAGIC:-42}"

if [ -z "$CONTAINER" ]; then
    echo "No Yaci DevKit container found. Start the devkit, or set YACI_DEVKIT_CONTAINER." >&2
    exit 1
fi

docker exec -i "$CONTAINER" sh -s -- "$MAGIC" <<'INNER' >&2
set -e
MAGIC="$1"
KEYS=/clusters/nodes/default/default-keys/utxo-keys

cardano-cli address build \
    --payment-verification-key-file "$KEYS/utxo1.vkey" \
    --testnet-magic "$MAGIC" \
    --out-file /tmp/yaci-test.addr
ADDR=$(cat /tmp/yaci-test.addr)

# Largest UTxO at the address, as TxHash#TxIx.
UTXO=$(cardano-cli query utxo --address "$ADDR" --testnet-magic "$MAGIC" \
    | awk 'NR > 2 { print $1"#"$2, $3 }' | sort -k2 -nr | head -1 | awk '{print $1}')

if [ -z "$UTXO" ]; then
    echo "No UTxOs at $ADDR — is the devnet funded?" >&2
    exit 1
fi

cardano-cli conway transaction build \
    --tx-in "$UTXO" \
    --tx-out "$ADDR+1000000000" \
    --change-address "$ADDR" \
    --testnet-magic "$MAGIC" \
    --out-file /tmp/yaci-test.raw

cardano-cli conway transaction sign \
    --tx-file /tmp/yaci-test.raw \
    --signing-key-file "$KEYS/utxo1.skey" \
    --testnet-magic "$MAGIC" \
    --out-file /tmp/yaci-test.signed
INNER

docker exec "$CONTAINER" cat /tmp/yaci-test.signed \
    | python3 -c 'import json, sys; print(json.load(sys.stdin)["cborHex"])'
