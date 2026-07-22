import Foundation

final class TemporarySkillLibrary {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "SpellbookScannerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    @discardableResult
    func write(_ contents: String, at relativePath: String) throws -> URL {
        let destination = url.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: destination)
        return destination
    }

    @discardableResult
    func write(_ data: Data, at relativePath: String) throws -> URL {
        let destination = url.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination)
        return destination
    }

    func makeDirectory(at relativePath: String) throws -> URL {
        let destination = url.appending(path: relativePath, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        return destination
    }
}
