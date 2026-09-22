import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import Testing
@testable import SwiftYaciAPI

// MARK: - Opt-in

/// Integration tests run against a real Yaci Store instance — a Yaci DevKit node,
/// or any store you point them at:
///
/// ```bash
/// YACI_BASE_URL=http://localhost:8080 swift test
/// ```
///
/// Without `YACI_BASE_URL` the whole suite is skipped, so `swift test` stays
/// hermetic by default and CI does not need a node.
///
/// Every test here is read-only. Nothing is submitted to the chain.
enum Integration {
    static var baseURL: String? {
        guard let value = ProcessInfo.processInfo.environment["YACI_BASE_URL"],
              !value.isEmpty else { return nil }
        return value
    }

    static var isEnabled: Bool { baseURL != nil }

    /// A signed transaction, as CBOR hex, that the node has not seen yet.
    ///
    /// Submitting spends the transaction's input, so a fresh one is needed per
    /// run. `scripts/devkit-signed-tx.sh` builds one against a running DevKit:
    ///
    /// ```bash
    /// export YACI_TEST_TX_HEX="$(./scripts/devkit-signed-tx.sh)"
    /// ```
    static var signedTxHex: String? {
        guard let value = ProcessInfo.processInfo.environment["YACI_TEST_TX_HEX"],
              !value.isEmpty else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var hasSignedTx: Bool { isEnabled && signedTxHex != nil }

    /// The transaction bytes, for the endpoints that take raw CBOR rather than hex.
    static func signedTxBytes() throws -> Data {
        let hex = try #require(signedTxHex)
        var bytes = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(try #require(UInt8(hex[index..<next], radix: 16)))
            index = next
        }
        return bytes
    }

    static func client() throws -> Yaci {
        try Yaci(basePath: baseURL ?? Yaci.defaultServerURL.absoluteString)
    }
}

// MARK: - Live suite

@Suite("Live Yaci Store", .enabled(if: Integration.isEnabled), .serialized)
struct LiveYaciStoreTests {
    let yaci: Yaci

    init() throws {
        yaci = try Integration.client()
    }

    // MARK: Blocks

    @Test("Latest block decodes")
    func latestBlock() async throws {
        let block = try await yaci.client.getLatestBlock().ok.body.json

        let number = try #require(block.number)
        #expect(number > 0)
        #expect(block.hash?.count == 64)
        #expect(block.slot ?? 0 > 0)
        #expect(block.epoch ?? -1 >= 0)
    }

    @Test("Block list decodes and pages")
    func blocks() async throws {
        let page = try await yaci.client.getBlocks(query: .init(page: 0, count: 5)).ok.body.json

        let blocks = try #require(page.blocks)
        #expect(!blocks.isEmpty)
        #expect(blocks.count <= 5)
        #expect(blocks.first?.number ?? 0 > 0)
    }

    @Test("Block by number round-trips against the latest block")
    func blockByNumber() async throws {
        let latest = try await yaci.client.getLatestBlock().ok.body.json
        let number = try #require(latest.number)

        let block = try await yaci.client.getBlockByNumber(
            path: .init(numberOrHash: String(number))
        ).ok.body.json

        #expect(block.number == number)
        #expect(block.hash == latest.hash)
    }

    // MARK: Epochs

    @Test("Latest epoch decodes")
    func latestEpoch() async throws {
        let epoch = try await yaci.client.getLatestEpoch().ok.body.json
        #expect(epoch.epoch ?? -1 >= 0)
    }

    @Test("Epoch list decodes")
    func epochs() async throws {
        let page = try await yaci.client.getEpochs(query: .init(page: 0, count: 5)).ok.body.json
        #expect(page.epochs != nil)
    }

    @Test("Latest protocol parameters decode")
    func protocolParams() async throws {
        let params = try await yaci.client.getLatestProtocolParams().ok.body.json

        #expect(params.minFeeA ?? 0 > 0)
        #expect(params.minFeeB ?? 0 > 0)
        #expect(params.maxTxSize ?? 0 > 0)
        #expect(params.protocolMajorVer ?? 0 > 0)
    }

    // MARK: Transactions

    @Test("Transaction list decodes")
    func transactions() async throws {
        let page = try await yaci.client.getTransactions(query: .init(page: 0, count: 5)).ok.body.json
        #expect(page.transactionSummaries != nil)
    }

    @Test("Transaction details decode")
    func transactionDetails() async throws {
        let summaries = try await yaci.client
            .getTransactions(query: .init(page: 0, count: 1)).ok.body.json
            .transactionSummaries
        let hash = try #require(summaries?.first?.txHash, "no transactions indexed yet")

        let tx = try await yaci.client.getTransaction(path: .init(txHash: hash)).ok.body.json
        #expect(tx.hash == hash)
        #expect(tx.outputs?.isEmpty == false)
    }

    @Test("Transaction UTxOs decode")
    func transactionUtxos() async throws {
        let summaries = try await yaci.client
            .getTransactions(query: .init(page: 0, count: 1)).ok.body.json
            .transactionSummaries
        let hash = try #require(summaries?.first?.txHash, "no transactions indexed yet")

        let utxos = try await yaci.client
            .getTransactionInputsOutputs(path: .init(txHash: hash)).ok.body.json
        #expect(utxos.outputs?.isEmpty == false)
    }

    @Test("Transaction witnesses decode")
    func transactionWitnesses() async throws {
        let summaries = try await yaci.client
            .getTransactions(query: .init(page: 0, count: 1)).ok.body.json
            .transactionSummaries
        let hash = try #require(summaries?.first?.txHash, "no transactions indexed yet")

        let witnesses = try await yaci.client
            .getTransactionWitnesses(path: .init(txHash: hash)).ok.body.json
        #expect(witnesses.allSatisfy { $0.txHash == hash })
    }

    // MARK: UTxOs and addresses

    @Test("Address UTxOs decode")
    func addressUtxos() async throws {
        let address = try await firstOutputAddress()

        let utxos = try await yaci.client.getUtxos1(
            path: .init(address: address),
            query: .init(count: 10, page: 0, order: .asc)
        ).ok.body.json

        #expect(utxos.allSatisfy { $0.address == address })
    }

    @Test("UTxO by transaction hash and index decodes")
    func utxoByKey() async throws {
        let summaries = try await yaci.client
            .getTransactions(query: .init(page: 0, count: 1)).ok.body.json
            .transactionSummaries
        let hash = try #require(summaries?.first?.txHash, "no transactions indexed yet")

        let utxo = try await yaci.client.getUtxo(path: .init(txHash: hash, index: 0)).ok.body.json
        #expect(utxo.txHash == hash)
        #expect(utxo.outputIndex == 0)
    }

    @Test("UTxOs by key list decodes")
    func utxosByKeyList() async throws {
        let summaries = try await yaci.client
            .getTransactions(query: .init(page: 0, count: 1)).ok.body.json
            .transactionSummaries
        let hash = try #require(summaries?.first?.txHash, "no transactions indexed yet")

        let utxos = try await yaci.client.getUtxos(
            body: .json([.init(txHash: hash, outputIndex: 0)])
        ).ok.body.json

        #expect(utxos.first?.txHash == hash)
    }

    @Test("Address balance and amounts decode")
    func addressBalance() async throws {
        let address = try await firstOutputAddress()

        let balance = try await yaci.client
            .getAddressBalance(path: .init(address: address)).ok.body.json
        #expect(balance.address == address)

        let amounts = try await yaci.client
            .getAddressAmounts(path: .init(address: address)).ok.body.json
        #expect(amounts.allSatisfy { $0.unit != nil })
    }

    // MARK: Governance

    @Test("Committee members decode")
    func committeeMembers() async throws {
        let committee = try await yaci.client.getCommitteeMembers().ok.body.json
        #expect(committee.thresholdDenominator ?? 0 > 0)
    }

    @Test("Governance proposals decode")
    func govActionProposals() async throws {
        let proposals = try await yaci.client
            .getGovActionProposalList(query: .init(page: 0, count: 5)).ok.body.json
        #expect(proposals.count <= 5)
    }

    // MARK: Endpoints with no data on a fresh devkit
    //
    // A freshly started Yaci DevKit has indexed only the genesis transactions —
    // no assets, scripts, pools or dreps. These tests still exercise URL
    // construction and the empty/absent paths through the client.

    @Test("Asset UTxOs for an unknown unit decode as an empty list")
    func assetUtxosEmpty() async throws {
        let unit = String(repeating: "ab", count: 28) + "4d494e"
        let utxos = try await yaci.client.getAssetUtxos(
            path: .init(unit: unit),
            query: .init(page: 0, count: 5)
        ).ok.body.json
        #expect(utxos.isEmpty)
    }

    @Test("Metadata by label decodes")
    func metadataByLabel() async throws {
        let output = try await yaci.client.getMetadataByLabel(
            path: .init(label: "674"),
            query: .init(page: 0, count: 5)
        )
        guard case let .ok(response) = output else { return }  // no metadata indexed
        let entries = try response.body.json
        #expect(entries.allSatisfy { $0.txHash?.count == 64 })
    }

    @Test("An unknown script reports a non-200 status")
    func unknownScript() async throws {
        let output = try await yaci.client.getScriptByHash(
            path: .init(scriptHash: String(repeating: "0", count: 56))
        )
        guard case let .undocumented(statusCode, _) = output else {
            Issue.record("Expected an undocumented response for an unknown script")
            return
        }
        #expect(statusCode == 404)
    }

    // MARK: Error paths

    @Test("An unknown transaction reports a non-200 status")
    func unknownTransaction() async throws {
        let absent = String(repeating: "0", count: 64)
        let output = try await yaci.client.getTransaction(path: .init(txHash: absent))

        guard case let .undocumented(statusCode, _) = output else {
            Issue.record("Expected an undocumented response for an unknown transaction")
            return
        }
        #expect(statusCode >= 400)
    }

    // MARK: Helpers

    /// An address that appears in the outputs of the most recent transaction.
    private func firstOutputAddress() async throws -> String {
        let summaries = try await yaci.client
            .getTransactions(query: .init(page: 0, count: 1)).ok.body.json
            .transactionSummaries
        return try #require(
            summaries?.first?.outputAddresses?.first,
            "no transactions indexed yet"
        )
    }
}


// MARK: - Submission and evaluation

/// `/tx/submit` and `/utils/txs/evaluate` are the two endpoints that reach past
/// the index to the node itself, and the two SwiftCardanoChain depends on most.
///
/// The rejection tests need nothing but a running store. The round trip needs a
/// freshly signed transaction in `YACI_TEST_TX_HEX` — see ``Integration/signedTxHex``.
@Suite("Live transaction submission", .enabled(if: Integration.isEnabled), .serialized)
struct LiveTransactionTests {
    let yaci: Yaci

    init() throws {
        yaci = try Integration.client()
    }

    @Test("Malformed CBOR is rejected with the node's error")
    func rejectsMalformedSubmission() async throws {
        let output = try await yaci.client.submitTx1(
            body: .applicationCbor(HTTPBody(Data([0xAB, 0xCD, 0xEF])))
        )

        guard case let .undocumented(statusCode, payload) = output else {
            Issue.record("Expected malformed CBOR to be rejected, got \(output)")
            return
        }
        #expect(statusCode == 400)

        // The node's own decoder error is passed through, which is what makes a
        // failed submission diagnosable.
        let body = try await String(collecting: payload.body ?? .init(""), upTo: 8192)
        #expect(body.contains("DeserialiseFailure"))
    }

    @Test("Malformed hex is rejected by the evaluator")
    func rejectsMalformedEvaluation() async throws {
        let output = try await yaci.client.evaluateTx(
            body: .applicationCbor(HTTPBody(Data("84a30081825820".utf8)))
        )

        guard case let .undocumented(statusCode, _) = output else {
            Issue.record("Expected malformed hex to be rejected, got \(output)")
            return
        }
        #expect(statusCode == 400)
    }

    @Test(
        "A real transaction evaluates and submits",
        .enabled(if: Integration.hasSignedTx)
    )
    func evaluateThenSubmit() async throws {
        let hex = try #require(Integration.signedTxHex)

        // Evaluate first: it does not consume the transaction's input, so it can
        // run against the same transaction the submission below spends.
        // The endpoint takes the transaction as hex text under a CBOR content type.
        let v6 = try await yaci.client.evaluateTx(
            query: .init(version: 6),
            body: .applicationCbor(HTTPBody(Data(hex.utf8)))
        )
        let v6Payload = try v6.accepted.body.json
        #expect(v6Payload.value["jsonrpc"] as? String == "2.0")
        // A payment transaction runs no scripts, so the budget list is empty.
        #expect(v6Payload.value["result"] as? [Any] != nil)

        let v5 = try await yaci.client.evaluateTx(
            body: .applicationCbor(HTTPBody(Data(hex.utf8)))
        )
        let v5Payload = try v5.accepted.body.json
        #expect(v5Payload.value["servicename"] as? String == "ogmios")
        #expect((v5Payload.value["result"] as? [String: Any])?["EvaluationResult"] != nil)

        // Submit. Yaci Store answers 202, and the body is the transaction hash.
        let submitted = try await yaci.client.submitTx1(
            body: .applicationCbor(HTTPBody(try Integration.signedTxBytes()))
        )
        let hash = try submitted.accepted.body.json
        let isHex = hash.allSatisfy(\.isHexDigit)
        #expect(hash.count == 64)
        #expect(isHex)

        // The transaction really reached the chain: wait for the indexer to catch up.
        var indexed: Components.Schemas.TransactionDetails?
        for _ in 0..<20 {
            if case let .ok(response) = try await yaci.client.getTransaction(
                path: .init(txHash: hash)
            ) {
                indexed = try response.body.json
                break
            }
            try await Task.sleep(for: .milliseconds(500))
        }

        let transaction = try #require(indexed, "submitted transaction was never indexed")
        #expect(transaction.hash == hash)
        #expect(transaction.blockHeight ?? 0 > 0)
        #expect(transaction.outputs?.isEmpty == false)
    }
}
