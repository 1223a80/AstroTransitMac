import Foundation

struct BackendProgressUpdate: Equatable, Sendable {
    let progress: Double
    let label: String?
}

/// Shared JSONL parser for backend stderr progress. It preserves partial lines
/// across chunks and keeps the complete stderr stream for terminal errors.
final class BackendProgressLineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var accumulated = Data()
    private var pending = Data()

    func append(_ data: Data) -> [BackendProgressUpdate] {
        lock.lock()
        accumulated.append(data)
        pending.append(data)
        var lines: [Data] = []
        while let newline = pending.firstIndex(of: 0x0A) {
            lines.append(pending[..<newline])
            pending.removeSubrange(...newline)
        }
        lock.unlock()

        return lines.compactMap { line in
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line),
                  let dictionary = object as? [String: Any],
                  let progress = dictionary["progress"] as? Double
            else { return nil }
            return BackendProgressUpdate(
                progress: min(max(progress, 0), 1),
                label: dictionary["label"] as? String
            )
        }
    }

    func allData() -> Data {
        lock.lock()
        let data = accumulated
        lock.unlock()
        return data
    }
}
