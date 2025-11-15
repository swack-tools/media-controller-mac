import Foundation
import Network

// MARK: - Networking Helpers

extension OnkyoClient {
    class ResumedFlag {
        var value = false
    }

    func createConnection() -> NWConnection {
        return NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: Self.defaultPort),
            using: .tcp
        )
    }

    func createReadHandler(
        connection: NWConnection,
        expectingPrefix: String,
        resumed: ResumedFlag,
        continuation: CheckedContinuation<String, Error>
    ) -> () -> Void {
        func readNextResponse() {
            let context = ResponseContext(
                resumed: resumed,
                continuation: continuation,
                readNext: readNextResponse
            )
            readResponse(
                connection: connection,
                expectingPrefix: expectingPrefix,
                context: context
            )
        }
        return readNextResponse
    }

    func readResponse(
        connection: NWConnection,
        expectingPrefix: String,
        context: ResponseContext
    ) {
        // Read eISCP header (16 bytes)
        connection.receive(minimumIncompleteLength: 16, maximumLength: 16) { headerData, _, _, headerError in
            guard headerError == nil, let headerData = headerData, headerData.count == 16 else {
                if !context.resumed.value {
                    context.resumed.value = true
                    connection.cancel()
                    context.continuation.resume(throwing: OnkyoClientError.connectionFailed("Header read failed"))
                }
                return
            }

            let dataSize = headerData[8..<12].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            self.readMessage(
                connection: connection,
                dataSize: Int(dataSize),
                expectingPrefix: expectingPrefix,
                context: context
            )
        }
    }

    func readMessage(
        connection: NWConnection,
        dataSize: Int,
        expectingPrefix: String,
        context: ResponseContext
    ) {
        connection.receive(minimumIncompleteLength: dataSize, maximumLength: dataSize) { messageData, _, _, error in
            guard error == nil,
                  let messageData = messageData,
                  let responseString = String(data: messageData, encoding: .utf8) else {
                if !context.resumed.value {
                    context.resumed.value = true
                    connection.cancel()
                    context.continuation.resume(throwing: OnkyoClientError.invalidResponse)
                }
                return
            }

            if responseString.contains(expectingPrefix) {
                if !context.resumed.value {
                    context.resumed.value = true
                    connection.cancel()
                    context.continuation.resume(returning: responseString)
                }
            } else {
                context.readNext()
            }
        }
    }

    func setupConnectionStateHandler(
        connection: NWConnection,
        packet: Data,
        resumed: ResumedFlag,
        continuation: CheckedContinuation<String, Error>,
        readHandler: @escaping () -> Void
    ) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: packet, completion: .contentProcessed { error in
                    if let error = error {
                        if !resumed.value {
                            resumed.value = true
                            connection.cancel()
                            continuation.resume(throwing: OnkyoClientError.connectionFailed(error.localizedDescription))
                        }
                    } else {
                        readHandler()
                    }
                })
            case .failed(let error), .waiting(let error):
                if !resumed.value {
                    resumed.value = true
                    connection.cancel()
                    continuation.resume(throwing: OnkyoClientError.connectionFailed(error.localizedDescription))
                }
            default:
                break
            }
        }
    }

    func setupTimeout(
        queue: DispatchQueue,
        connection: NWConnection,
        resumed: ResumedFlag,
        continuation: CheckedContinuation<String, Error>,
        timeout: TimeInterval
    ) {
        queue.asyncAfter(deadline: .now() + timeout) {
            if !resumed.value {
                resumed.value = true
                connection.cancel()
                continuation.resume(throwing: OnkyoClientError.timeout)
            }
        }
    }

    struct ResponseContext {
        let resumed: ResumedFlag
        let continuation: CheckedContinuation<String, Error>
        let readNext: () -> Void
    }
}
