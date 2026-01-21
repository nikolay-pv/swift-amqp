extension Channel {
    public static func withChannel<T>(
        on connection: Connection,
        _ handler: @Sendable (Result<Channel, Error>) async throws -> T
    )
        async rethrows -> T
    {
        do {
            let channel = try await connection.makeChannel()
            let result = try await handler(.success(channel))
            // ignore exceptions here to make sure that handler is not called twice (because I'm not sure what would that mean for the caller)
            try? await channel.close()
            return result
        } catch {
            return try await handler(.failure(error))
        }
    }
}
