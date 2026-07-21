import Foundation
import Darwin

public enum GaugeSnapshotStoreError: Error, Equatable, LocalizedError, Sendable {
    case appGroupContainerUnavailable(String)
    case fileLockFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case let .appGroupContainerUnavailable(identifier):
            "The App Group container \(identifier) is unavailable."
        case let .fileLockFailed(code):
            "The shared snapshot lock failed with POSIX error \(code)."
        }
    }
}

/// Atomic JSON persistence shared by the app and widget extension.
public final class GaugeSnapshotStore: @unchecked Sendable {
    public static let appGroupIdentifier = "group.com.drolidotnet.Gauge"
    public static let defaultFileName = "gauge-snapshot.json"
    public static let shared = GaugeSnapshotStore()

    private let appGroupIdentifier: String?
    private let configuredDirectoryURL: URL?
    private let fileName: String
    private let fileManager: FileManager
    /// `NSLock` covers multiple store instances in this process; `flock`
    /// below covers the app and widget extension as separate processes.
    private static let processLock = NSLock()

    public init(
        appGroupIdentifier: String = GaugeSnapshotStore.appGroupIdentifier,
        fileName: String = GaugeSnapshotStore.defaultFileName,
        fileManager: FileManager = .default
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        configuredDirectoryURL = nil
        self.fileName = fileName
        self.fileManager = fileManager
    }

    public init(
        directoryURL: URL,
        fileName: String = GaugeSnapshotStore.defaultFileName,
        fileManager: FileManager = .default
    ) {
        appGroupIdentifier = nil
        configuredDirectoryURL = directoryURL
        self.fileName = fileName
        self.fileManager = fileManager
    }

    public var snapshotURL: URL? {
        try? resolvedSnapshotURL()
    }

    public func load() throws -> GaugeSnapshot? {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }

        let source = try resolvedSnapshotURL()
        guard fileManager.fileExists(atPath: source.path) else { return nil }
        return try withCrossProcessLock(for: source) {
            try load(from: source)
        }
    }

    /// Saves only if the incoming snapshot is newer than the on-disk value.
    /// Returns `true` when the file was replaced and `false` when a newer or
    /// identical snapshot was already present.
    @discardableResult
    public func save(_ snapshot: GaugeSnapshot) throws -> Bool {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        let destination = try resolvedSnapshotURL()
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        return try withCrossProcessLock(for: destination) {
            // A corrupt legacy cache must not permanently prevent a new
            // last-good snapshot from repairing the file.
            if let existing = try? load(from: destination),
               existing.fetchedAt >= snapshot.fetchedAt {
                return false
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: destination, options: .atomic)
            return true
        }
    }

    private func load(from source: URL) throws -> GaugeSnapshot? {
        guard fileManager.fileExists(atPath: source.path) else { return nil }

        let data = try Data(contentsOf: source, options: .mappedIfSafe)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(GaugeSnapshot.self, from: data)
    }

    private func withCrossProcessLock<Result>(
        for snapshotURL: URL,
        _ operation: () throws -> Result
    ) throws -> Result {
        let lockURL = snapshotURL.appendingPathExtension("lock")
        let descriptor = lockURL.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return Darwin.open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else {
            throw GaugeSnapshotStoreError.fileLockFailed(errno)
        }
        defer { Darwin.close(descriptor) }

        guard flock(descriptor, LOCK_EX) == 0 else {
            throw GaugeSnapshotStoreError.fileLockFailed(errno)
        }
        defer { flock(descriptor, LOCK_UN) }

        return try operation()
    }

    private func resolvedSnapshotURL() throws -> URL {
        if let configuredDirectoryURL {
            return configuredDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
        }

        let identifier = appGroupIdentifier ?? Self.appGroupIdentifier
        guard let directory = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            throw GaugeSnapshotStoreError.appGroupContainerUnavailable(identifier)
        }
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }
}
