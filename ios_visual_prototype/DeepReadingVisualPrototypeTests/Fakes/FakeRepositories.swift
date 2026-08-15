import Foundation
@testable import DeepReadingVisualPrototype

final class FakeSupabaseReadingAssetRemote: SupabaseReadingAssetRemote, @unchecked Sendable {
    struct RPCCall {
        let name: String
        let parameters: [String: Any]
    }

    var lastRPC: RPCCall?
    var rpcAssetID: UUID = UUID()
    var rowsByTable: [String: [[String: Any]]] = [:]

    func rpcReturningUUID(name: String, parameters: [String: Any]) async throws -> UUID {
        lastRPC = RPCCall(name: name, parameters: parameters)
        return rpcAssetID
    }

    func rpc(name: String, parameters: [String: Any]) async throws {
        lastRPC = RPCCall(name: name, parameters: parameters)
    }

    func readRows(from table: String) async throws -> [[String: Any]] {
        rowsByTable[table] ?? []
    }
}
