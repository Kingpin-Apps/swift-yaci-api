import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import SwiftYaciAPI

// MARK: - Recorded requests

/// Captures the requests a ``MockTransport`` handled, so tests can assert on the
/// path, query and header fields the generated client produced.
///
/// `ClientTransport.send` is not isolated to any actor, so the storage is guarded
/// by a lock rather than relying on the main actor.
final class RequestRecorder: @unchecked Sendable {
    /// A request the transport handled, with its body already collected.
    struct Entry {
        let request: HTTPRequest
        let body: Data?
    }

    private let lock = NSLock()
    private var storage: [Entry] = []

    var entries: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var requests: [HTTPRequest] { entries.map(\.request) }
    var last: HTTPRequest? { requests.last }
    var lastBody: Data? { entries.last?.body }

    func record(_ request: HTTPRequest, body: Data?) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(Entry(request: request, body: body))
    }
}

// MARK: - Mock transport

/// A `ClientTransport` that answers from ``Fixture`` instead of the network.
///
/// Operations without a fixture answer `404`, which the generated client surfaces
/// as `.undocumented` — the same shape a real Yaci Store instance produces for an
/// unknown resource.
struct MockTransport: ClientTransport {
    let recorder: RequestRecorder?

    init(recorder: RequestRecorder? = nil) {
        self.recorder = recorder
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var requestBody: Data?
        if let body {
            requestBody = try await Data(collecting: body, upTo: 1 << 20)
        }
        recorder?.record(request, body: requestBody)

        guard let response = Fixture.responses[operationID] else {
            return (HTTPResponse(status: .notFound), nil)
        }
        return (
            HTTPResponse(
                status: response.status,
                headerFields: [.contentType: response.contentType]
            ),
            .init(Data(response.body.utf8))
        )
    }
}

/// A canned response: the status, content type and body a Yaci Store instance
/// returns for one operation.
struct MockResponse {
    var status: HTTPResponse.Status = .ok
    var contentType: String = "application/json"
    var body: String
}

// MARK: - Payloads

/// Response payloads keyed by operation ID, written as the JSON a Yaci Store
/// instance returns so that the generated `CodingKeys` are exercised too.
enum Fixture {
    static let blockHash = "d2d2d2b2cbd8a25d8e6f1f2b36c8ad9b6c5c0d5c9ad4cbbd2a0c0f4e0b1a2c3d"
    static let txHash = "38bb4f1e46b7c8a3a0e4f7b0a1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e"
    static let address = "addr_test1qz2fxv2umyhttkxyxp8x0dlpdt3k6cwng5pxj3jhsydzer3n0d3vllmyl"
        + "kd9sdfd6ryn5u8k3nvsdjzvk5vqkgkhrzqgnjycc"
    static let stakeAddress = "stake_test1uqrw9tjymlm3sf6shcn6urqmzjgrqmgqkjnwqaz4kgnnqcqgpqmpx"
    static let policyId = "d27197682d71905c087c5c3b61b10e6d746db0b9bef351014d75bb26"
    static let unit = policyId + "4d494e"
    static let scriptHash = "6f2d1a5f1d7fe80b8d2b8d5c7f3b0a9e8d7c6b5a4938271605f4e3d2"

    /// Canned responses keyed by operation ID. Most are a `200` with a JSON body;
    /// `/tx/submit` and `/utils/txs/evaluate` answer `202`, which is what a real
    /// instance does on success.
    static let responses: [String: MockResponse] = [
        Operations.GetLatestBlock.id: .init(body: block),
        Operations.GetBlockByNumber.id: .init(body: block),
        Operations.GetBlocks.id: .init(body: blocksPage),
        Operations.GetLatestEpoch.id: .init(body: latestEpoch),
        Operations.GetEpochByNumber.id: .init(body: epoch),
        Operations.GetEpochs.id: .init(body: epochsPage),
        Operations.GetLatestProtocolParams.id: .init(body: protocolParams),
        Operations.GetUtxos.id: .init(body: addressUtxos),
        Operations.GetUtxo.id: .init(body: addressUtxo),
        Operations.GetUtxos1.id: .init(body: utxos),
        Operations.GetAddressBalance.id: .init(body: addressBalance),
        Operations.GetAddressAmounts.id: .init(body: addressAmounts),
        Operations.GetStakeAccountDetails.id: .init(body: stakeAccountInfo),
        Operations.GetStakeAddressBalance.id: .init(body: stakeAddressBalance),
        Operations.GetTransaction.id: .init(body: transactionDetails),
        Operations.GetTransactionWitnesses.id: .init(body: transactionWitnesses),
        Operations.GetSupplyByUnit.id: .init(body: unitSupply),
        Operations.GetScriptByHash.id: .init(body: script),
        Operations.GetCommitteeMembers.id: .init(body: committee),
        Operations.GetCurrentConstitution1.id: .init(body: constitution),
        Operations.SubmitTx1.id: .init(status: .accepted, body: submitted),
        Operations.EvaluateTx.id: .init(status: .accepted, body: evaluationV6),
        Operations.EvaluateTx1.id: .init(status: .accepted, body: evaluationV5),
    ]

    /// `/tx/submit` answers `202` with the transaction hash as a JSON string.
    static let submitted = "\"\(txHash)\""

    /// Ogmios v6 (`version=6`) shape: a JSON-RPC envelope whose result is a list
    /// of per-validator budgets.
    static let evaluationV6 = """
    {
      "jsonrpc": "2.0",
      "method": "evaluateTransaction",
      "result": [
        {
          "validator": { "purpose": "spend", "index": 0 },
          "budget": { "memory": 5236222, "cpu": 1212353 }
        }
      ]
    }
    """

    /// Ogmios v5 (the default) shape: a JSON-WSP envelope whose result is an
    /// `EvaluationResult` map keyed by `purpose:index`.
    static let evaluationV5 = """
    {
      "type": "jsonwsp/response",
      "version": "1.0",
      "servicename": "ogmios",
      "methodname": "EvaluateTx",
      "result": {
        "EvaluationResult": {
          "spend:0": { "memory": 5236222, "steps": 1212353 }
        }
      }
    }
    """

    static let block = """
    {
      "time": 1712345678,
      "height": 1234567,
      "number": 1234567,
      "hash": "\(blockHash)",
      "slot": 52348293,
      "epoch": 152,
      "era": 6,
      "epoch_slot": 148293,
      "slot_leader": "pool1qqqqpanw9zc0rzh0yha3rxcknrjzxvfcyx7kvxpj6qqqqqqqqqqq",
      "size": 4821,
      "tx_count": 12,
      "output": "8341234567",
      "fees": "2134567",
      "op_cert_counter": "7",
      "previous_block": "9c1f6b5d0a2e3c4b5a6978f0e1d2c3b4a5968778695a4b3c2d1e0f9a8b7c6d5e",
      "confirmations": 42
    }
    """

    static let blocksPage = """
    {
      "total": 2,
      "total_pages": 1,
      "blocks": [
        {
          "time": 1712345678,
          "number": 1234567,
          "slot": 52348293,
          "epoch": 152,
          "era": 6,
          "output": 8341234567,
          "fees": 2134567,
          "slot_leader": "pool1qqqqpanw9zc0rzh0yha3rxcknrjzxvfcyx7kvxpj6qqqqqqqqqqq",
          "size": 4821,
          "tx_count": 12
        },
        {
          "time": 1712345658,
          "number": 1234566,
          "slot": 52348273,
          "epoch": 152,
          "era": 6,
          "output": 1230000000,
          "fees": 174321,
          "slot_leader": "pool1p8mnhhjn6ycr6a9f8jcxhqcqs3qhqgpx9dqn2f8pqvqqqqqqqqq",
          "size": 1204,
          "tx_count": 3
        }
      ]
    }
    """

    static let latestEpoch = """
    {
      "epoch": 152,
      "start_time": 1712000000,
      "end_time": 1712432000,
      "first_block_time": 1712000021,
      "last_block_time": 1712345678,
      "block_count": 18234,
      "tx_count": 92341,
      "output": "78341234567890",
      "fees": "1234567890",
      "active_stake": "22341234567890123"
    }
    """

    static let epoch = """
    {
      "number": 151,
      "block_count": 21012,
      "transaction_count": 104233,
      "total_output": 91234567890123,
      "total_fees": 2345678901,
      "start_time": 1711568000,
      "end_time": 1712000000,
      "max_slot": 51916293
    }
    """

    static let epochsPage = """
    {
      "total": 2,
      "total_pages": 1,
      "epochs": [
        {
          "number": 152,
          "block_count": 18234,
          "transaction_count": 92341,
          "total_output": 78341234567890,
          "total_fees": 1234567890,
          "start_time": 1712000000,
          "end_time": 1712432000,
          "max_slot": 52348293
        },
        {
          "number": 151,
          "block_count": 21012,
          "transaction_count": 104233,
          "total_output": 91234567890123,
          "total_fees": 2345678901,
          "start_time": 1711568000,
          "end_time": 1712000000,
          "max_slot": 51916293
        }
      ]
    }
    """

    static let protocolParams = """
    {
      "min_fee_a": 44,
      "min_fee_b": 155381,
      "max_block_size": 90112,
      "max_tx_size": 16384,
      "max_block_header_size": 1100,
      "key_deposit": "2000000",
      "pool_deposit": "500000000",
      "e_max": 18,
      "n_opt": 500,
      "a0": 0.3,
      "rho": 0.003,
      "tau": 0.2,
      "decentralisation_param": 0.0,
      "protocol_major_ver": 10,
      "protocol_minor_ver": 0,
      "min_pool_cost": "170000000",
      "coins_per_utxo_size": "4310",
      "price_mem": 0.0577,
      "price_step": 0.0000721,
      "max_tx_ex_mem": "14000000",
      "max_tx_ex_steps": "10000000000",
      "max_val_size": "5000",
      "min_fee_ref_script_cost_per_byte": 15.0,
      "collateral_percent": 150,
      "max_collateral_inputs": 3,
      "drep_deposit": 500000000,
      "gov_action_deposit": 100000000000,
      "gov_action_lifetime": 6,
      "drep_activity": 20
    }
    """

    static let addressUtxo = """
    {
      "block_number": 1234567,
      "block_time": 1712345678,
      "tx_hash": "\(txHash)",
      "output_index": 0,
      "slot": 52348293,
      "block_hash": "\(blockHash)",
      "epoch": 152,
      "owner_addr": "\(address)",
      "owner_stake_addr": "\(stakeAddress)",
      "lovelace_amount": 9876543,
      "amounts": [
        { "unit": "lovelace", "quantity": 9876543 },
        {
          "unit": "\(unit)",
          "policy_id": "\(policyId)",
          "asset_name": "MIN",
          "quantity": 1500
        }
      ],
      "is_collateral_return": false
    }
    """

    static let addressUtxos = "[\(addressUtxo)]"

    static let utxos = """
    [
      {
        "tx_hash": "\(txHash)",
        "output_index": 0,
        "address": "\(address)",
        "amount": [
          { "unit": "lovelace", "quantity": "9876543" },
          {
            "unit": "\(unit)",
            "policy_id": "\(policyId)",
            "asset_name": "MIN",
            "quantity": "1500"
          }
        ],
        "epoch": 152,
        "block_number": 1234567,
        "block_time": 1712345678
      }
    ]
    """

    static let addressBalance = """
    {
      "block_number": 1234567,
      "block_time": 1712345678,
      "address": "\(address)",
      "amounts": [
        { "unit": "lovelace", "quantity": 9876543 },
        {
          "unit": "\(unit)",
          "policy_id": "\(policyId)",
          "asset_name": "MIN",
          "quantity": 1500
        }
      ],
      "slot": 52348293,
      "last_balance_calculation_block": 1234560
    }
    """

    /// `/addresses/{address}/amounts` returns `AddressAmount`, whose quantity is a
    /// number — unlike the `Amount` nested in a UTxO, which is a string. See
    /// the `SpecificationFixes` article.
    static let addressAmounts = """
    [
      { "unit": "lovelace", "quantity": 9876543 },
      {
        "unit": "\(unit)",
        "policy_id": "\(policyId)",
        "asset_name": "MIN",
        "quantity": 1500
      }
    ]
    """

    static let stakeAccountInfo = """
    {
      "stake_address": "\(stakeAddress)",
      "controlled_amount": 619154618165,
      "withdrawable_amount": 319154618165,
      "pool_id": "pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy"
    }
    """

    static let stakeAddressBalance = """
    {
      "block_number": 1234567,
      "block_time": 1712345678,
      "address": "\(stakeAddress)",
      "slot": 52348293,
      "quantity": 619154618165,
      "epoch": 152
    }
    """

    static let transactionDetails = """
    {
      "hash": "\(txHash)",
      "block_height": 1234567,
      "slot": 52348293,
      "inputs": [
        {
          "tx_hash": "1a2b3c4d5e6f708192a3b4c5d6e7f80912a3b4c5d6e7f8091a2b3c4d5e6f7081",
          "output_index": 1,
          "address": "\(address)",
          "amount": [{ "unit": "lovelace", "quantity": "12000000" }]
        }
      ],
      "outputs": [
        {
          "tx_hash": "\(txHash)",
          "output_index": 0,
          "address": "\(address)",
          "amount": [{ "unit": "lovelace", "quantity": "9876543" }]
        }
      ],
      "utxo_count": 2,
      "total_output": 9876543,
      "fees": 178921,
      "ttl": 52400000,
      "invalid": false
    }
    """

    static let transactionWitnesses = """
    [
      {
        "tx_hash": "\(txHash)",
        "index": 0,
        "pub_key": "8b2f0d1a4c6e8091a2b3c4d5e6f70819a2b3c4d5e6f70819a2b3c4d5e6f70819",
        "signature": "5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b",
        "pub_keyhash": "\(scriptHash)",
        "type": "VKEY_WITNESS"
      }
    ]
    """

    static let unitSupply = """
    { "unit": "\(unit)", "supply": 3000000000000000 }
    """

    static let script = """
    {
      "script_hash": "\(scriptHash)",
      "type": "plutusV3",
      "serialised_size": 1024
    }
    """

    static let committee = """
    {
      "threshold_numerator": 2,
      "threshold_denominator": 3,
      "members": [
        {
          "hash": "5b1a8d2c3e4f50617283949a5b6c7d8e9f0a1b2c3d4e5f6071829304",
          "cred_type": "ADDR_KEYHASH",
          "start_epoch": 140,
          "expired_epoch": 200
        },
        {
          "hash": "6c2b9e3d4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c",
          "cred_type": "SCRIPTHASH",
          "start_epoch": 145,
          "expired_epoch": 210
        }
      ]
    }
    """

    static let constitution = """
    {
      "active_epoch": 150,
      "anchor_url": "https://raw.githubusercontent.com/cardano-foundation/constitution/main/constitution.txt",
      "anchor_hash": "ca41a91f399259bcefe57f9858e91f6d00e1a38d6d9c63d4052914ea7bd70cb2"
    }
    """

}
