import CoreServices
import Dispatch
import Foundation

final class FSEventWatcher: @unchecked Sendable {
    private let callbackBox: FSEventCallbackBox
    private let stream: FSEventStreamRef
    private let queue = DispatchQueue(label: "com.keding.Spellbook.fsevents", qos: .utility)
    private var isStopped = false

    init?(paths: [String], handler: @escaping @Sendable ([String]) -> Void) {
        guard !paths.isEmpty else { return nil }
        callbackBox = FSEventCallbackBox(handler: handler)
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(callbackBox).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagWatchRoot
                | kFSEventStreamCreateFlagUseCFTypes
        )
        guard let stream = FSEventStreamCreate(
            nil,
            spellbookFSEventCallback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.35,
            flags
        ) else { return nil }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    deinit {
        stop()
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }
}

private func spellbookFSEventCallback(
    _ stream: ConstFSEventStreamRef,
    _ contextInfo: UnsafeMutableRawPointer?,
    _ eventCount: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIDs: UnsafePointer<FSEventStreamEventId>
) {
    guard eventCount > 0, let contextInfo else { return }
    let box = Unmanaged<FSEventCallbackBox>.fromOpaque(contextInfo).takeUnretainedValue()
    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] ?? []
    box.handler(paths)
}
