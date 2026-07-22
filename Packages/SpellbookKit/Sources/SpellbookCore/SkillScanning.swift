import Foundation

public protocol SkillScanning: Sendable {
    func scan() -> AsyncThrowingStream<ScanUpdate, any Error>
}

