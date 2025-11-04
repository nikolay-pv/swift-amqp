import Testing

@testable import AMQP

@Test(
    "forEachChunk splits data into correct chunks",
    arguments: [
        (
            data: Array(0..<10), maxChunkSize: 3,
            expectedChunks: [[0, 1, 2], [3, 4, 5], [6, 7, 8], [9]]
        ),
        (data: Array(0..<5), maxChunkSize: 2, expectedChunks: [[0, 1], [2, 3], [4]]),
        (data: Array(0..<4), maxChunkSize: 4, expectedChunks: [[0, 1, 2, 3]]),
        (data: [], maxChunkSize: 3, expectedChunks: []),
    ]
)
func forEachChunkTest(data: [Int], maxChunkSize: Int, expectedChunks: [[Int]])
    async throws
{
    var chunked = [[Int]]()
    forEachChunk(
        of: data,
        maxChunkSize: maxChunkSize,
        perform: {
            chunked.append(.init($0))
        }
    )
    #expect(chunked == expectedChunks)
}
