import Foundation
import Network

@available(macOS 13.0, *)
class AndroidTVConnection {
    private var connection: NWConnection?
    private(set) var serverCertificate: SecCertificate?
    private let queue = DispatchQueue(label: "androidtv.connection")
    private var certificateStore: CertificateStore?

    enum ConnectionError: LocalizedError {
        case connectionFailed(String)
        case tlsSetupFailed(String)
        case sendFailed(String)
        case receiveFailed(String)

        var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg): return "Connection failed: \(msg)"
            case .tlsSetupFailed(let msg): return "TLS setup failed: \(msg)"
            case .sendFailed(let msg): return "Send failed: \(msg)"
            case .receiveFailed(let msg): return "Receive failed: \(msg)"
            }
        }
    }

    /// Connect to Shield TV with TLS
    func connect(
        host: String,
        port: UInt16,
        useTLS: Bool = true,
        certificateStore: CertificateStore? = nil
    ) async throws {
        self.certificateStore = certificateStore

        let tlsOptions: NWProtocolTLS.Options?

        if useTLS {
            tlsOptions = try setupTLS()
        } else {
            tlsOptions = nil
        }

        let params: NWParameters
        if let tls = tlsOptions {
            params = NWParameters(tls: tls)
        } else {
            params = .tcp
        }

        let endpoint = NWEndpoint.Host(host)
        let portEndpoint = NWEndpoint.Port(integerLiteral: port)

        connection = NWConnection(host: endpoint, port: portEndpoint, using: params)

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false

            connection?.stateUpdateHandler = { [weak self] state in
                guard !resumed else { return }

                switch state {
                case .ready:
                    resumed = true

                    // Capture server certificate from TLS metadata
                    if useTLS,
                       let conn = self?.connection,
                       let tlsMetadata = conn.metadata(
                           definition: NWProtocolTLS.definition
                       ) as? NWProtocolTLS.Metadata {
                        let secMetadata = tlsMetadata.securityProtocolMetadata

                        // Iterate through peer certificates to get the first one
                        sec_protocol_metadata_access_peer_certificate_chain(secMetadata) { secCert in
                            // This block is called once per certificate in the chain
                            // We want the first one (leaf certificate)
                            if self?.serverCertificate == nil {
                                // sec_certificate_t is already a SecCertificate
                                self?.serverCertificate = sec_certificate_copy_ref(secCert).takeRetainedValue()
                            }
                        }
                    }

                    continuation.resume()

                case .failed(let error):
                    resumed = true
                    continuation.resume(throwing: ConnectionError.connectionFailed(error.localizedDescription))

                case .cancelled:
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: ConnectionError.connectionFailed("Connection cancelled"))
                    }

                default:
                    break
                }
            }

            connection?.start(queue: queue)
        }
    }

    /// Send data
    func send(_ data: Data) async throws {
        guard let connection = connection else {
            throw ConnectionError.sendFailed("Not connected")
        }

        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: ConnectionError.sendFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Receive data
    private func receive(minLength: Int = 1, maxLength: Int = 1024) async throws -> Data {
        guard let connection = connection else {
            throw ConnectionError.receiveFailed("Not connected")
        }

        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(
                minimumIncompleteLength: minLength,
                maximumLength: maxLength
            ) { data, _, _, error in
                if let error = error {
                    continuation.resume(throwing: ConnectionError.receiveFailed(error.localizedDescription))
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: ConnectionError.receiveFailed("No data received"))
                }
            }
        }
    }

    /// Receive a complete message with varint length prefix
    func receiveMessage(timeout: TimeInterval = 10.0) async throws -> Data {
        // Use timeout wrapper
        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                // Read varint length prefix
                var length = 0
                var shift = 0
                while true {
                    let byte = try await self.receive(minLength: 1, maxLength: 1)
                    guard let byteValue = byte.first else {
                        throw ConnectionError.receiveFailed("Failed to read length byte")
                    }

                    length |= Int(byteValue & 0x7F) << shift

                    if (byteValue & 0x80) == 0 {
                        break
                    }

                    shift += 7
                    if shift > 28 {
                        throw ConnectionError.receiveFailed("Length varint too long")
                    }
                }

                // Read the message of the specified length
                if length == 0 {
                    return Data()
                }

                return try await self.receive(minLength: length, maxLength: length)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw ConnectionError.receiveFailed("Timeout")
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Send a message with varint length prefix (protobuf style)
    func sendMessage(_ data: Data) async throws {
        var message = Data()

        // Encode length as varint (protobuf standard)
        var length = data.count
        while length >= 0x80 {
            message.append(UInt8((length & 0x7F) | 0x80))
            length >>= 7
        }
        message.append(UInt8(length & 0x7F))

        message.append(data)
        try await send(message)
    }

    /// Disconnect
    func disconnect() {
        connection?.cancel()
        connection = nil
    }

    // MARK: - TLS Setup

    private func setupTLS() throws -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()

        // Load identity from certificate store
        guard let store = certificateStore else {
            throw ConnectionError.tlsSetupFailed("No certificate store provided")
        }

        let identity = try store.loadIdentity()

        // Set up TLS with client certificate
        sec_protocol_options_set_local_identity(
            options.securityProtocolOptions,
            sec_identity_create(identity)!
        )

        // Skip server certificate validation (self-signed certs)
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { _, _, complete in
            complete(true)
        }, queue)

        return options
    }
}
