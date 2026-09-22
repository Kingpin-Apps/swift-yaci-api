import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@testable import SwiftYaciAPI

// MARK: - Helpers

private func makeYaci(recorder: RequestRecorder? = nil) throws -> Yaci {
    try Yaci(
        client: Client(
            serverURL: Yaci.defaultServerURL,
            transport: MockTransport(recorder: recorder)
        )
    )
}

// MARK: - Client configuration

@Suite("Yaci Client Configuration")
struct YaciClientConfigurationTests {
    @Test("Defaults to the local Yaci Store instance")
    func defaultBaseURL() throws {
        let yaci = try Yaci()
        #expect(yaci.baseURL == URL(string: "http://localhost:8080")!)
        #expect(yaci.baseURL == Yaci.defaultServerURL)
        #expect(yaci.apiKey == nil)
    }

    @Test("Uses a custom base path")
    func customBasePath() throws {
        let yaci = try Yaci(basePath: "https://yaci.example.com:9090")
        #expect(yaci.baseURL.absoluteString == "https://yaci.example.com:9090")
    }

    @Test("Rejects a base path that is not a URL", arguments: ["", "http://exa mple.com"])
    func invalidBasePath(_ basePath: String) throws {
        #expect(throws: YaciAPIError.self) {
            _ = try Yaci(basePath: basePath)
        }
    }

    @Test("Rejects a base path without a scheme and host")
    func relativeBasePath() throws {
        #expect(throws: YaciAPIError.self) {
            _ = try Yaci(basePath: "localhost:8080")
        }
    }

    @Test("Keeps an explicitly supplied API key")
    func explicitAPIKey() throws {
        let yaci = try Yaci(apiKey: "secret-token")
        #expect(yaci.apiKey == "secret-token")
    }

    @Test("Reads the API key from an environment variable")
    func apiKeyFromEnvironment() throws {
        let name = "YACI_API_KEY_TEST_\(UUID().uuidString.prefix(8))"
        setenv(name, "env-token", 1)
        defer { unsetenv(name) }

        let yaci = try Yaci(environmentVariable: name)
        #expect(yaci.apiKey == "env-token")
    }

    @Test("An explicit API key wins over the environment variable")
    func explicitAPIKeyWinsOverEnvironment() throws {
        let name = "YACI_API_KEY_TEST_\(UUID().uuidString.prefix(8))"
        setenv(name, "env-token", 1)
        defer { unsetenv(name) }

        let yaci = try Yaci(apiKey: "explicit-token", environmentVariable: name)
        #expect(yaci.apiKey == "explicit-token")
    }

    @Test("Throws when the environment variable is missing or empty")
    func missingEnvironmentVariable() throws {
        let missing = "YACI_API_KEY_TEST_MISSING_\(UUID().uuidString.prefix(8))"
        #expect(throws: YaciAPIError.self) {
            _ = try Yaci(environmentVariable: missing)
        }

        let empty = "YACI_API_KEY_TEST_EMPTY_\(UUID().uuidString.prefix(8))"
        setenv(empty, "", 1)
        defer { unsetenv(empty) }
        #expect(throws: YaciAPIError.self) {
            _ = try Yaci(environmentVariable: empty)
        }
    }

    @Test("Uses an injected client")
    func injectedClient() async throws {
        let recorder = RequestRecorder()
        let yaci = try makeYaci(recorder: recorder)

        _ = try await yaci.client.getLatestBlock()

        #expect(recorder.requests.count == 1)
        #expect(recorder.last?.path == "/api/v1/blocks/latest")
    }
}

// MARK: - Errors

@Suite("Yaci API Errors")
struct YaciAPIErrorTests {
    @Test("Carries the supplied message")
    func customMessages() {
        #expect(YaciAPIError.invalidBasePath("bad path").description == "bad path")
        #expect(YaciAPIError.missingAPIKey("no key").description == "no key")
        #expect(YaciAPIError.valueError("bad value").description == "bad value")
    }

    @Test("Falls back to a default message")
    func defaultMessages() {
        #expect(YaciAPIError.invalidBasePath(nil).description == "Invalid base path.")
        #expect(YaciAPIError.missingAPIKey(nil).description == "The API Key is missing.")
        #expect(YaciAPIError.valueError(nil).description == "The value is invalid.")
    }

    @Test("Is equatable")
    func equatable() {
        #expect(YaciAPIError.missingAPIKey("a") == YaciAPIError.missingAPIKey("a"))
        #expect(YaciAPIError.missingAPIKey("a") != YaciAPIError.missingAPIKey("b"))
        #expect(YaciAPIError.missingAPIKey("a") != YaciAPIError.valueError("a"))
    }

    @Test("An unknown resource surfaces as an undocumented response")
    func undocumentedResponse() async throws {
        let yaci = try makeYaci()

        // No fixture is registered for this operation, so the transport answers 404.
        let output = try await yaci.client.getScriptJsonByHash(
            path: .init(scriptHash: Fixture.scriptHash)
        )

        guard case let .undocumented(statusCode, _) = output else {
            Issue.record("Expected an undocumented response, got \(output)")
            return
        }
        #expect(statusCode == 404)
    }
}

// MARK: - Authentication middleware

@Suite("Authentication Middleware")
struct AuthenticationMiddlewareTests {
    private func authorizationHeader(for key: String) async throws -> String? {
        let middleware = AuthenticationMiddleware(authorizationHeaderFieldValue: key)
        var seen: HTTPRequest?
        _ = try await middleware.intercept(
            HTTPRequest(method: .get, scheme: "http", authority: "localhost:8080", path: "/api/v1/blocks/latest"),
            body: nil,
            baseURL: Yaci.defaultServerURL,
            operationID: Operations.GetLatestBlock.id,
            next: { request, _, _ in
                seen = request
                return (HTTPResponse(status: .ok), nil)
            }
        )
        return seen?.headerFields[.authorization]
    }

    @Test("Adds a Bearer prefix to a raw token")
    func addsBearerPrefix() async throws {
        #expect(try await authorizationHeader(for: "secret-token") == "Bearer secret-token")
    }

    @Test("Leaves an already-formatted token alone", arguments: ["Bearer secret-token", "bearer secret-token"])
    func keepsExistingPrefix(_ token: String) async throws {
        #expect(try await authorizationHeader(for: token) == token)
    }
}

// MARK: - Blocks

@Suite("Block Endpoints")
struct BlockEndpointTests {
    let yaci: Yaci
    let recorder = RequestRecorder()

    init() throws {
        yaci = try makeYaci(recorder: recorder)
    }

    @Test("Latest block")
    func latestBlock() async throws {
        let block = try await yaci.client.getLatestBlock().ok.body.json

        #expect(block.hash == Fixture.blockHash)
        #expect(block.number == 1234567)
        #expect(block.height == 1234567)
        #expect(block.slot == 52348293)
        #expect(block.epoch == 152)
        #expect(block.epochSlot == 148293)
        #expect(block.txCount == 12)
        #expect(block.size == 4821)
        #expect(block.output == "8341234567")
        #expect(block.fees == "2134567")
        #expect(block.opCertCounter == "7")
        #expect(block.confirmations == 42)
        #expect(block.slotLeader?.hasPrefix("pool1") == true)
        #expect(recorder.last?.path == "/api/v1/blocks/latest")
    }

    @Test("Block by number")
    func blockByNumber() async throws {
        let block = try await yaci.client.getBlockByNumber(
            path: .init(numberOrHash: "1234567")
        ).ok.body.json

        #expect(block.number == 1234567)
        #expect(recorder.last?.path == "/api/v1/blocks/1234567")
    }

    @Test("Paged block list passes page and count through")
    func blocks() async throws {
        let page = try await yaci.client.getBlocks(
            query: .init(page: 2, count: 25)
        ).ok.body.json

        #expect(page.total == 2)
        #expect(page.totalPages == 1)
        #expect(page.blocks?.count == 2)
        #expect(page.blocks?.first?.number == 1234567)
        #expect(page.blocks?.first?.txCount == 12)
        #expect(page.blocks?.last?.number == 1234566)

        let query = recorder.last?.path
        #expect(query?.hasPrefix("/api/v1/blocks?") == true)
        #expect(query?.contains("page=2") == true)
        #expect(query?.contains("count=25") == true)
    }
}

// MARK: - Epochs

@Suite("Epoch Endpoints")
struct EpochEndpointTests {
    let yaci: Yaci
    let recorder = RequestRecorder()

    init() throws {
        yaci = try makeYaci(recorder: recorder)
    }

    @Test("Latest epoch")
    func latestEpoch() async throws {
        let epoch = try await yaci.client.getLatestEpoch().ok.body.json

        #expect(epoch.epoch == 152)
        #expect(epoch.blockCount == 18234)
        #expect(epoch.txCount == 92341)
        #expect(epoch.output == "78341234567890")
        #expect(epoch.fees == "1234567890")
        #expect(epoch.activeStake == "22341234567890123")
        #expect(recorder.last?.path == "/api/v1/epochs/latest")
    }

    @Test("Epoch by number")
    func epochByNumber() async throws {
        let epoch = try await yaci.client.getEpochByNumber(
            path: .init(number: 151)
        ).ok.body.json

        #expect(epoch.number == 151)
        #expect(epoch.blockCount == 21012)
        #expect(epoch.transactionCount == 104233)
        #expect(epoch.totalOutput == 91234567890123)
        #expect(epoch.maxSlot == 51916293)
        #expect(recorder.last?.path == "/api/v1/epochs/151")
    }

    @Test("Epoch list")
    func epochs() async throws {
        let page = try await yaci.client.getEpochs(query: .init(page: 0, count: 10)).ok.body.json

        #expect(page.total == 2)
        #expect(page.epochs?.count == 2)
        #expect(page.epochs?.first?.number == 152)
    }

    @Test("Latest protocol parameters")
    func latestProtocolParams() async throws {
        let params = try await yaci.client.getLatestProtocolParams().ok.body.json

        #expect(params.minFeeA == 44)
        #expect(params.minFeeB == 155381)
        #expect(params.maxTxSize == 16384)
        #expect(params.maxBlockSize == 90112)
        #expect(params.keyDeposit == "2000000")
        #expect(params.poolDeposit == "500000000")
        #expect(params.minPoolCost == "170000000")
        #expect(params.protocolMajorVer == 10)
        #expect(params.protocolMinorVer == 0)
        #expect(params.a0 == 0.3)
        #expect(params.decentralisationParam == 0.0)
        #expect(params.coinsPerUtxoSize == "4310")
        #expect(params.priceMem == 0.0577)
        #expect(params.collateralPercent == 150)
        #expect(params.maxCollateralInputs == 3)
        #expect(params.govActionDeposit == 100_000_000_000)
        #expect(params.drepDeposit == 500_000_000)
        #expect(params.govActionLifetime == 6)
        #expect(params.minFeeRefScriptCostPerByte == 15.0)
        #expect(recorder.last?.path == "/api/v1/epochs/latest/parameters")
    }
}

// MARK: - UTxOs

@Suite("UTxO Endpoints")
struct UtxoEndpointTests {
    let yaci: Yaci
    let recorder = RequestRecorder()

    init() throws {
        yaci = try makeYaci(recorder: recorder)
    }

    @Test("UTxOs by key sends the requested outputs as JSON")
    func utxosByKey() async throws {
        let utxos = try await yaci.client.getUtxos(
            body: .json([.init(txHash: Fixture.txHash, outputIndex: 0)])
        ).ok.body.json

        #expect(utxos.count == 1)

        let utxo = try #require(utxos.first)
        #expect(utxo.txHash == Fixture.txHash)
        #expect(utxo.outputIndex == 0)
        #expect(utxo.ownerAddr == Fixture.address)
        #expect(utxo.ownerStakeAddr == Fixture.stakeAddress)
        #expect(utxo.lovelaceAmount == 9876543)
        #expect(utxo.isCollateralReturn == false)
        #expect(utxo.amounts?.count == 2)
        #expect(utxo.amounts?.first?.unit == "lovelace")
        #expect(utxo.amounts?.last?.policyId == Fixture.policyId)
        #expect(utxo.amounts?.last?.assetName == "MIN")
        #expect(utxo.amounts?.last?.quantity == 1500)

        #expect(recorder.last?.method == .post)
        #expect(recorder.last?.path == "/api/v1/utxos")
    }

    @Test("Single UTxO by transaction hash and index")
    func utxoByHashAndIndex() async throws {
        let utxo = try await yaci.client.getUtxo(
            path: .init(txHash: Fixture.txHash, index: 0)
        ).ok.body.json

        #expect(utxo.txHash == Fixture.txHash)
        #expect(utxo.blockHash == Fixture.blockHash)
        #expect(utxo.epoch == 152)
        #expect(recorder.last?.path == "/api/v1/utxos/\(Fixture.txHash)/0")
    }

    @Test("Address UTxOs honour paging and ordering")
    func addressUtxos() async throws {
        let utxos = try await yaci.client.getUtxos1(
            path: .init(address: Fixture.address),
            query: .init(count: 50, page: 1, order: .desc)
        ).ok.body.json

        let utxo = try #require(utxos.first)
        #expect(utxo.address == Fixture.address)
        #expect(utxo.txHash == Fixture.txHash)
        #expect(utxo.amount?.count == 2)
        #expect(utxo.amount?.first?.quantity == "9876543")

        let path = try #require(recorder.last?.path)
        #expect(path.hasPrefix("/api/v1/addresses/\(Fixture.address)/utxos?"))
        #expect(path.contains("count=50"))
        #expect(path.contains("page=1"))
        #expect(path.contains("order=desc"))
    }
}

// MARK: - Addresses and accounts

@Suite("Address and Account Endpoints")
struct AddressAndAccountEndpointTests {
    let yaci: Yaci
    let recorder = RequestRecorder()

    init() throws {
        yaci = try makeYaci(recorder: recorder)
    }

    @Test("Address balance")
    func addressBalance() async throws {
        let balance = try await yaci.client.getAddressBalance(
            path: .init(address: Fixture.address)
        ).ok.body.json

        #expect(balance.address == Fixture.address)
        #expect(balance.blockNumber == 1234567)
        #expect(balance.slot == 52348293)
        #expect(balance.lastBalanceCalculationBlock == 1234560)
        #expect(balance.amounts?.count == 2)
        #expect(balance.amounts?.first?.quantity == 9876543)
        #expect(recorder.last?.path == "/api/v1/addresses/\(Fixture.address)/balance")
    }

    @Test("Address amounts")
    func addressAmounts() async throws {
        let amounts = try await yaci.client.getAddressAmounts(
            path: .init(address: Fixture.address)
        ).ok.body.json

        #expect(amounts.count == 2)
        #expect(amounts.first?.unit == "lovelace")
        #expect(amounts.last?.unit == Fixture.unit)
        #expect(amounts.last?.assetName == "MIN")
    }

    @Test("Stake account details")
    func stakeAccountDetails() async throws {
        let account = try await yaci.client.getStakeAccountDetails(
            path: .init(stakeAddress: Fixture.stakeAddress)
        ).ok.body.json

        #expect(account.stakeAddress == Fixture.stakeAddress)
        #expect(account.controlledAmount == 619154618165)
        #expect(account.withdrawableAmount == 319154618165)
        #expect(account.poolId == "pool1pu5jlj4q9w9jlxeu370a3c9myx47md5j5m2str0naunn2q3lkdy")
        #expect(recorder.last?.path == "/api/v1/accounts/\(Fixture.stakeAddress)")
    }

    @Test("Stake address balance")
    func stakeAddressBalance() async throws {
        let balance = try await yaci.client.getStakeAddressBalance(
            path: .init(stakeAddress: Fixture.stakeAddress)
        ).ok.body.json

        #expect(balance.address == Fixture.stakeAddress)
        #expect(balance.quantity == 619154618165)
        #expect(balance.epoch == 152)
        #expect(recorder.last?.path == "/api/v1/accounts/\(Fixture.stakeAddress)/balance")
    }
}

// MARK: - Transactions

@Suite("Transaction Endpoints")
struct TransactionEndpointTests {
    let yaci: Yaci
    let recorder = RequestRecorder()

    init() throws {
        yaci = try makeYaci(recorder: recorder)
    }

    @Test("Transaction details")
    func transactionDetails() async throws {
        let tx = try await yaci.client.getTransaction(
            path: .init(txHash: Fixture.txHash)
        ).ok.body.json

        #expect(tx.hash == Fixture.txHash)
        #expect(tx.blockHeight == 1234567)
        #expect(tx.slot == 52348293)
        #expect(tx.fees == 178921)
        #expect(tx.totalOutput == 9876543)
        #expect(tx.utxoCount == 2)
        #expect(tx.invalid == false)
        #expect(tx.inputs?.count == 1)
        #expect(tx.outputs?.first?.address == Fixture.address)
        #expect(recorder.last?.path == "/api/v1/txs/\(Fixture.txHash)")
    }

    @Test("Transaction witnesses")
    func transactionWitnesses() async throws {
        let witnesses = try await yaci.client.getTransactionWitnesses(
            path: .init(txHash: Fixture.txHash)
        ).ok.body.json

        let witness = try #require(witnesses.first)
        #expect(witness.txHash == Fixture.txHash)
        #expect(witness.index == 0)
        #expect(witness._type == .vkeyWitness)
        #expect(witness.pubKeyhash == Fixture.scriptHash)
        #expect(recorder.last?.path == "/api/v1/txs/\(Fixture.txHash)/witnesses")
    }

    @Test("Submitting a transaction returns the hash from a 202")
    func submitTransaction() async throws {
        let cbor = Data(repeating: 0xAB, count: 32)
        let output = try await yaci.client.submitTx1(body: .applicationCbor(HTTPBody(cbor)))

        // Yaci Store answers 202, not 200, when the node accepts a transaction.
        let hash = try output.accepted.body.json
        #expect(hash == Fixture.txHash)

        #expect(recorder.last?.method == .post)
        #expect(recorder.last?.path == "/api/v1/tx/submit")
        #expect(recorder.last?.headerFields[.contentType] == "application/cbor")
        // The raw transaction bytes go on the wire untouched.
        #expect(recorder.lastBody == cbor)
    }

    @Test("Evaluating a transaction returns the Ogmios v6 payload from a 202")
    func evaluateTransactionV6() async throws {
        let hex = "84a30081825820"
        let output = try await yaci.client.evaluateTx(
            query: .init(version: 6),
            body: .applicationCbor(HTTPBody(Data(hex.utf8)))
        )

        let payload = try output.accepted.body.json
        #expect(payload.value["jsonrpc"] as? String == "2.0")

        let result = try #require(payload.value["result"] as? [[String: Any]])
        let budget = try #require(result.first?["budget"] as? [String: Any])
        #expect(budget["memory"] as? Int == 5236222)
        #expect(budget["cpu"] as? Int == 1212353)

        // The endpoint takes the transaction as hex text, under a CBOR content type.
        #expect(recorder.lastBody == Data(hex.utf8))
        #expect(recorder.last?.headerFields[.contentType] == "application/cbor")

        let path = try #require(recorder.last?.path)
        #expect(path.hasPrefix("/api/v1/utils/txs/evaluate?"))
        #expect(path.contains("version=6"))
    }

    @Test("Evaluating with additional UTxOs returns the Ogmios v5 payload")
    func evaluateTransactionV5() async throws {
        let output = try await yaci.client.evaluateTx1(
            body: .json(.init(cbor: "84a30081825820", additionalUtxoSet: []))
        )

        let payload = try output.accepted.body.json
        #expect(payload.value["servicename"] as? String == "ogmios")

        let result = try #require(payload.value["result"] as? [String: Any])
        let evaluation = try #require(result["EvaluationResult"] as? [String: Any])
        let spend = try #require(evaluation["spend:0"] as? [String: Any])
        #expect(spend["memory"] as? Int == 5236222)
        #expect(spend["steps"] as? Int == 1212353)

        #expect(recorder.last?.path == "/api/v1/utils/txs/evaluate/utxos")
    }

    @Test("A rejected submission surfaces the node's status code")
    func rejectedSubmission() async throws {
        // No fixture for this operation, so the transport answers 404 — the same
        // shape a real rejection (400) takes through the generated client.
        let rejecting = try Yaci(
            client: Client(serverURL: Yaci.defaultServerURL, transport: RejectingTransport())
        )
        let output = try await rejecting.client.submitTx1(
            body: .applicationCbor(HTTPBody(Data(repeating: 0xAB, count: 4)))
        )

        guard case let .undocumented(statusCode, payload) = output else {
            Issue.record("Expected an undocumented response for a rejected submission")
            return
        }
        #expect(statusCode == 400)

        let body = try await String(collecting: payload.body ?? .init(""), upTo: 4096)
        #expect(body.contains("DeserialiseFailure"))
    }
}

/// Answers the way Yaci Store does when the node rejects a transaction: `400`
/// with the node's error message wrapped in JSON.
private struct RejectingTransport: ClientTransport {
    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let error = #"""
        {"status_code":400,"error":"400 BAD_REQUEST","message":"{\"contents\":[\"DecoderErrorDeserialiseFailure \\\"Shelley Tx\\\" (DeserialiseFailure 0 \\\"expected list len or indef\\\")\"]}"}
        """#
        return (
            HTTPResponse(status: .badRequest, headerFields: [.contentType: "application/json"]),
            .init(Data(error.utf8))
        )
    }
}

// MARK: - Assets, scripts and governance

@Suite("Asset, Script and Governance Endpoints")
struct AssetScriptGovernanceEndpointTests {
    let yaci: Yaci
    let recorder = RequestRecorder()

    init() throws {
        yaci = try makeYaci(recorder: recorder)
    }

    @Test("Asset supply by unit")
    func supplyByUnit() async throws {
        let supply = try await yaci.client.getSupplyByUnit(
            path: .init(unit: Fixture.unit)
        ).ok.body.json

        #expect(supply.unit == Fixture.unit)
        #expect(supply.supply == 3_000_000_000_000_000)
        #expect(recorder.last?.path == "/api/v1/assets/\(Fixture.unit)/supply")
    }

    @Test("Script by hash")
    func scriptByHash() async throws {
        let script = try await yaci.client.getScriptByHash(
            path: .init(scriptHash: Fixture.scriptHash)
        ).ok.body.json

        #expect(script.scriptHash == Fixture.scriptHash)
        #expect(script._type == .plutusV3)
        #expect(script.serialisedSize == 1024)
        #expect(recorder.last?.path == "/api/v1/scripts/\(Fixture.scriptHash)")
    }

    @Test("Current committee members")
    func committeeMembers() async throws {
        let committee = try await yaci.client.getCommitteeMembers().ok.body.json

        #expect(committee.thresholdNumerator == 2)
        #expect(committee.thresholdDenominator == 3)
        #expect(committee.members?.count == 2)
        #expect(committee.members?.first?.credType == .addrKeyhash)
        #expect(committee.members?.first?.startEpoch == 140)
        #expect(committee.members?.last?.credType == .scripthash)
        #expect(recorder.last?.path == "/api/v1/governance/committees/current")
    }

    @Test("Current constitution")
    func currentConstitution() async throws {
        let constitution = try await yaci.client.getCurrentConstitution1().ok.body.json

        #expect(constitution.activeEpoch == 150)
        #expect(constitution.anchorHash == "ca41a91f399259bcefe57f9858e91f6d00e1a38d6d9c63d4052914ea7bd70cb2")
        #expect(constitution.anchorUrl?.hasPrefix("https://") == true)
        #expect(recorder.last?.path == "/api/v1/governance/constitution")
    }
}
