#!/usr/bin/env python3
"""Re-apply the local fixes that Yaci Store's generated OpenAPI document needs.

Yaci Store publishes its OpenAPI document from Springdoc, which gets two things
wrong for a generated client:

1. Every response body is declared under the `*/*` media type, because the
   controllers do not set `produces`. swift-openapi-generator cannot attach a
   schema to a wildcard, so it emits an untyped `HTTPBody` and the schema is
   lost. Responses with a concrete schema are rewritten to `application/json`.

   Free-form `type: object` responses (`/tx/submit` and the two
   `/utils/txs/evaluate` endpoints) keep `*/*`: they pass a node or Ogmios
   payload straight through, so an untyped body is the honest representation.

2. A handful of fields are declared as integers but serialised by Jackson as
   JSON strings, which makes the generated models fail to decode against a real
   instance. Those are retyped to `string` to match the wire format.

3. The two endpoints that talk to the node — `/tx/submit` and
   `/utils/txs/evaluate` — answer `202 Accepted` on success, but only `200` is
   documented, so every successful call decodes as `.undocumented`. Their
   responses are declared properly.

4. Two different Java DTOs are published under the single name `Amount`, and
   they disagree: nested in a UTxO its `quantity` is a string, while
   `/addresses/{address}/amounts` returns it as a number. The endpoint's
   response is repointed at a separate `AddressAmount` schema so each one
   decodes.

Idempotent — safe to run after every refresh of the spec.
"""
import sys
from pathlib import Path

WILDCARD = '"*/*":'

# (schema, property) pairs Springdoc declares as integers but that Yaci Store
# sends as JSON strings. Verified against a live instance; see
# the SpecificationFixes article in the DocC catalog.
STRING_TYPED_NUMBERS = {
    ("BlockDto", "output"),
    ("BlockDto", "fees"),
    ("BlockDto", "op_cert_counter"),
    ("Amount", "quantity"),
}


def concrete_schema(lines: list[str], start: int, indent: int) -> bool:
    """Is the schema under the media type at `start` a concrete, decodable model?

    True for a `$ref` or an array; false for a free-form `type: object` or a
    bare scalar, where there is no generated model to decode into.
    """
    schema_indent = None
    for line in lines[start + 1:]:
        stripped = line.strip()
        if not stripped:
            continue
        line_indent = len(line) - len(line.lstrip())
        if line_indent <= indent:
            break
        if stripped == "schema:":
            schema_indent = line_indent
            continue
        if schema_indent is None or line_indent != schema_indent + 2:
            continue  # only the schema's own top-level keys decide this
        if stripped.startswith('"$ref"') or stripped.startswith("$ref"):
            return True
        if stripped == "type: array":
            return True
        if stripped.startswith("type:"):
            return False
    return False


def rewrite_media_types(lines: list[str]) -> tuple[list[str], int]:
    """Fix 1 — `*/*` response media types that carry a real schema."""
    changed = 0
    for i, line in enumerate(lines):
        if line.strip() != WILDCARD:
            continue
        indent = len(line) - len(line.lstrip())
        if concrete_schema(lines, i, indent):
            lines[i] = " " * indent + "application/json:"
            changed += 1
    return lines, changed


def retype_as_string(lines: list[str]) -> tuple[list[str], int]:
    """Fix 2 — properties declared as integers that arrive as JSON strings."""
    out: list[str] = []
    changed = 0
    schema: str | None = None
    prop: str | None = None
    drop_format = False

    for line in lines:
        stripped = line.strip()
        indent = len(line) - len(line.lstrip())

        if drop_format:
            drop_format = False
            if stripped.startswith("format:"):
                continue  # the format no longer applies to a string

        if indent == 4 and stripped.endswith(":"):
            schema, prop = stripped[:-1], None
        elif indent == 8 and stripped.endswith(":"):
            prop = stripped[:-1]
        elif (
            indent == 10
            and stripped == "type: integer"
            and (schema, prop) in STRING_TYPED_NUMBERS
        ):
            out.append(" " * indent + "type: string")
            drop_format = True
            changed += 1
            continue

        out.append(line)

    return out, changed


AMOUNTS_PATH = '"/api/v1/addresses/{address}/amounts":'

ADDRESS_AMOUNT_SCHEMA = """    AddressAmount:
      type: object
      properties:
        unit:
          type: string
        policy_id:
          type: string
        asset_name:
          type: string
        quantity:
          type: integer"""


def split_address_amount(lines: list[str]) -> tuple[list[str], int]:
    """Fix 4 — give `/addresses/{address}/amounts` its own `AddressAmount` schema."""
    if any(line.strip() == "AddressAmount:" for line in lines):
        return lines, 0  # already applied

    changed = 0

    # Repoint the endpoint's response at the new schema.
    in_path = False
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == AMOUNTS_PATH:
            in_path = True
            continue
        if in_path:
            if line and not line.startswith("    "):
                break  # left the path block
            if stripped == '"$ref": "#/components/schemas/Amount"':
                lines[i] = line.replace("/Amount", "/AddressAmount")
                changed += 1
                break

    if not changed:
        return lines, 0  # endpoint missing; leave the schema out too

    # Insert the schema definition after `Amount`.
    out: list[str] = []
    for line in lines:
        if line == "    Amount:":
            out += ADDRESS_AMOUNT_SCHEMA.split("\n")
            changed += 1
        out.append(line)

    return out, changed


# Operations that answer 202 on success, with the media type and schema of the
# body they actually return. Verified against a live instance by submitting and
# evaluating a real signed transaction.
NODE_OPERATIONS = {
    "submitTx_1": (
        "type: string",
        "Accepted. The node took the transaction; the body is its hash.",
    ),
    "evaluateTx": (
        "type: object",
        "Accepted. The body is the Ogmios evaluation result.",
    ),
    "evaluateTx_1": (
        "type: object",
        "Accepted. The body is the Ogmios evaluation result.",
    ),
}


def declare_accepted(lines: list[str]) -> tuple[list[str], int]:
    """Fix 3 — document the `202` that `/tx/submit` and `/utils/txs/evaluate` return."""
    out: list[str] = []
    changed = 0
    operation: str | None = None
    skipping = False

    def already_applied(start: int) -> bool:
        """True when this operation's responses already declare a 202."""
        for line in lines[start + 1:]:
            stripped = line.strip()
            if stripped and len(line) - len(line.lstrip()) <= 6:
                return False
            if stripped == "'202':":
                return True
        return False

    for index, line in enumerate(lines):
        stripped = line.strip()
        indent = len(line) - len(line.lstrip())

        if skipping:
            # Drop the old single-response block, up to the next sibling key.
            if stripped and indent > 6:
                continue
            skipping = False

        if stripped.startswith("operationId: "):
            operation = stripped.removeprefix("operationId: ")

        if (
            stripped == "responses:"
            and operation in NODE_OPERATIONS
            and not already_applied(index)
        ):
            schema, accepted_description = NODE_OPERATIONS[operation]
            out.append(line)
            for status, description in (
                ("200", "OK"),
                ("202", accepted_description),
            ):
                out += [
                    f"        '{status}':",
                    f"          description: {description}",
                    "          content:",
                    "            application/json:",
                    "              schema:",
                    f"                {schema}",
                ]
            changed += 1
            skipping = True
            continue

        out.append(line)

    return out, changed


def fix(path: Path) -> int:
    lines = path.read_text().split("\n")
    lines, media = rewrite_media_types(lines)
    lines, retyped = retype_as_string(lines)
    lines, accepted = declare_accepted(lines)
    lines, split = split_address_amount(lines)
    if media or retyped or accepted or split:
        path.write_text("\n".join(lines))
    return media + retyped + accepted + split


if __name__ == "__main__":
    targets = [Path(p) for p in sys.argv[1:]] or [
        Path("Sources/SwiftYaciAPI/openapi.yaml"),
        Path("openapi.yml"),
    ]
    for target in targets:
        print(f"{target}: applied {fix(target)} fixes")
