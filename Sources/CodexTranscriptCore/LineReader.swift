import Foundation

final class LineReader {
    private let handle: FileHandle
    private let chunkSize: Int
    private var buffer = Data()
    private var eof = false

    init(url: URL, chunkSize: Int = 64 * 1024) throws {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw TranscriptError.unreadableSession(url) }
        self.handle = handle
        self.chunkSize = chunkSize
    }

    deinit { try? handle.close() }

    func nextLine() throws -> Data? {
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer[..<newline]
                buffer.removeSubrange(...newline)
                return Data(line)
            }
            if eof {
                guard !buffer.isEmpty else { return nil }
                defer { buffer.removeAll(keepingCapacity: false) }
                return buffer
            }
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { eof = true } else { buffer.append(chunk) }
        }
    }
}
