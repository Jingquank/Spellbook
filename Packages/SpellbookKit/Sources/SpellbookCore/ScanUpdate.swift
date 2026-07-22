import Foundation

public enum ScanUpdate: Sendable {
    case progress(snapshot: LibrarySnapshot, scannedFileCount: Int)
    case finished(snapshot: LibrarySnapshot, scannedFileCount: Int)
}

