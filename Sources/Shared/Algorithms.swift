func forEachChunk<T: Collection>(
    of body: T,
    maxChunkSize: Int,
    perform: (T.SubSequence) -> Void
) {
    var startIndex = body.startIndex
    var endIndex =
        body.index(
            body.startIndex,
            offsetBy: maxChunkSize,
            limitedBy: body.endIndex
        ) ?? body.endIndex
    while startIndex != endIndex {
        perform(body[startIndex..<endIndex])
        startIndex =
            body.index(
                startIndex,
                offsetBy:
                    maxChunkSize,
                limitedBy: body.endIndex
            ) ?? body.endIndex
        endIndex =
            body.index(
                endIndex,
                offsetBy: maxChunkSize,
                limitedBy:
                    body.endIndex
            ) ?? body.endIndex
    }
}
