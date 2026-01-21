extension Connection {
    public static func connectThenClose<T>(
        with configuration: Configuration,
        andProperties properties: Spec.Table,
        _ handler: @Sendable (Result<Connection, Error>) async throws -> T
    ) async rethrows -> T {
        do {
            let connection = try await Connection(with: configuration, andProperties: properties)
            let result = try await handler(.success(connection))
            // ignore exceptions here to make sure that handler is not called twice (because I'm not sure what would that mean for the caller)
            try? await connection.close()
            return result
        } catch {
            return try await handler(.failure(error))
        }
    }

    public static func connectChannelThenClose<T>(
        with configuration: Configuration,
        andProperties properties: Spec.Table,
        _ handler: @Sendable (Result<Channel, Error>) async throws -> T
    ) async rethrows -> T {
        do {
            let connection = try await Connection(with: configuration, andProperties: properties)
            let channel = try await connection.makeChannel()
            let result = try await handler(.success(channel))
            // ignore exceptions here to make sure that handler is not called twice (because I'm not sure what would that mean for the caller)
            try? await channel.close()
            try? await connection.close()
            return result
        } catch {
            return try await handler(.failure(error))
        }
    }

    public func withChannel<T>(
        _ handler: @Sendable (Result<Channel, Error>) async throws -> T
    ) async rethrows -> T {
        do {
            let channel = try await self.makeChannel()
            let result = try await handler(.success(channel))
            // ignore exceptions here to make sure that handler is not called twice (because I'm not sure what would that mean for the caller)
            try? await channel.close()
            return result
        } catch {
            return try await handler(.failure(error))
        }
    }
}
