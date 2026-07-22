final class FSEventCallbackBox: @unchecked Sendable {
    let handler: @Sendable ([String]) -> Void

    init(handler: @escaping @Sendable ([String]) -> Void) {
        self.handler = handler
    }
}
