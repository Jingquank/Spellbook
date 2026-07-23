import AppKit
import Observation
import SwiftUI

enum InteractionModality: Sendable {
    case keyboard
    case pointer
}

@MainActor
@Observable
final class InteractionModalityModel {
    private(set) var current = InteractionModality.keyboard
    private var monitors: [Any] = []

    func start() {
        guard monitors.isEmpty else { return }

        if let keyboardMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown,
            handler: { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.current = .keyboard
                }
                return event
            }
        ) {
            monitors.append(keyboardMonitor)
        }

        let pointerEvents: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown
        ]
        if let pointerMonitor = NSEvent.addLocalMonitorForEvents(
            matching: pointerEvents,
            handler: { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.current = .pointer
                }
                return event
            }
        ) {
            monitors.append(pointerMonitor)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}

private struct InteractionModalityKey: EnvironmentKey {
    static let defaultValue = InteractionModality.keyboard
}

extension EnvironmentValues {
    var interactionModality: InteractionModality {
        get { self[InteractionModalityKey.self] }
        set { self[InteractionModalityKey.self] = newValue }
    }
}
