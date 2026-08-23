import Foundation
@testable import DeepReadingVisualPrototype

final class FakeSupabaseReadingAssetRemote: SupabaseReadingAssetRemote, @unchecked Sendable {
    struct RPCCall {
        let name: String
        let parameters: [String: Any]
    }

    var lastRPC: RPCCall?
    var rpcCalls: [RPCCall] = []
    var rpcAssetID: UUID = UUID()
    var rowsByTable: [String: [[String: Any]]] = [:]

    func rpcReturningUUID(name: String, parameters: [String: Any]) async throws -> UUID {
        let call = RPCCall(name: name, parameters: parameters)
        lastRPC = call
        rpcCalls.append(call)
        return rpcAssetID
    }

    func rpc(name: String, parameters: [String: Any]) async throws {
        let call = RPCCall(name: name, parameters: parameters)
        lastRPC = call
        rpcCalls.append(call)
    }

    func readRows(from table: String) async throws -> [[String: Any]] {
        rowsByTable[table] ?? []
    }
}

final class FakeSupabaseKnowledgeBaseRemote: SupabaseKnowledgeBaseRemote, @unchecked Sendable {
    typealias RPCCall = FakeSupabaseReadingAssetRemote.RPCCall

    var lastRPC: RPCCall?
    var currentOwnerID = UUID()
    var rowsByTable: [String: [[String: Any]]] = [:]

    func rpc(name: String, parameters: [String: Any]) async throws {
        lastRPC = RPCCall(name: name, parameters: parameters)
    }

    func readRows(from table: String) async throws -> [[String: Any]] {
        rowsByTable[table] ?? []
    }

    func readCurrentOwnerID() async throws -> UUID {
        currentOwnerID
    }
}
