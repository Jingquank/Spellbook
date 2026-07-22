import Foundation
import SpellbookCore

public actor FileSystemSkillManager: SkillManaging {
    private let roots: [SkillDiscoveryRoot]
    private let recoveryRoot: URL
    private let fileManager: FileManager
    private let catalog: (any CatalogStore)?
    private let faultInjector: (@Sendable (MutationCheckpoint) throws -> Void)?
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    public init(
        roots: [SkillDiscoveryRoot] = SkillDiscoveryRoot.known,
        recoveryRoot: URL? = nil,
        fileManager: FileManager = .default,
        catalog: (any CatalogStore)? = nil,
        faultInjector: (@Sendable (MutationCheckpoint) throws -> Void)? = nil
    ) {
        self.roots = roots
        self.fileManager = fileManager
        self.recoveryRoot = recoveryRoot ?? Self.defaultRecoveryRoot(fileManager: fileManager)
        self.catalog = catalog
        self.faultInjector = faultInjector
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func read(at url: URL) throws -> ManagedFileContent {
        let canonicalURL = url.standardizedFileURL
        guard let data = try? Data(contentsOf: canonicalURL, options: .mappedIfSafe) else {
            throw SkillMutationError.unreadable(canonicalURL)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw SkillMutationError.invalidText(canonicalURL)
        }
        return ManagedFileContent(
            url: canonicalURL,
            text: text,
            contentHash: StableHasher.sha256(data)
        )
    }

    public func plan(
        _ requests: [MutationRequest],
        kind: ManagedOperationKind
    ) async throws -> ManagedMutationPlan {
        let operationID = UUID().uuidString
        let startedAt = Date.now
        do {
        guard !requests.isEmpty else { throw SkillMutationError.invalidPlan }
        let destinations = requests.map { $0.destinationURL.standardizedFileURL }
        guard Set(destinations).count == destinations.count else {
            throw SkillMutationError.invalidPlan
        }

        let operationRoot = recoveryRoot.appending(path: operationID, directoryHint: .isDirectory)
        let stagingRoot = operationRoot.appending(path: "Staging", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: stagingRoot, withIntermediateDirectories: true)

        let targets = try requests.enumerated().map { index, request in
            let destinationURL = request.destinationURL.standardizedFileURL
            let existed = fileManager.fileExists(atPath: destinationURL.path)
            let current = existed ? try read(at: destinationURL) : nil
            try validateExpectedHash(
                request.expectedHash,
                current: current,
                destinationURL: destinationURL
            )

            switch request.action {
            case .write:
                guard let proposedText = request.proposedText else {
                    throw SkillMutationError.invalidPlan
                }
                let proposedData = Data(proposedText.utf8)
                let stagedURL = stagingRoot.appending(path: "\(index).candidate")
                try proposedData.write(to: stagedURL, options: .atomic)
                return MutationTargetPlan(
                    id: "target-\(index)",
                    destinationURL: destinationURL,
                    action: .write,
                    expectedHash: request.expectedHash,
                    proposedHash: StableHasher.sha256(proposedData),
                    originalText: current?.text,
                    proposedText: proposedText,
                    stagedURL: stagedURL,
                    diff: Self.diff(from: current?.text ?? "", to: proposedText)
                )
            case .remove:
                guard current != nil, request.proposedText == nil else {
                    throw SkillMutationError.invalidPlan
                }
                return MutationTargetPlan(
                    id: "target-\(index)",
                    destinationURL: destinationURL,
                    action: .remove,
                    expectedHash: request.expectedHash,
                    proposedHash: nil,
                    originalText: current?.text,
                    proposedText: nil,
                    stagedURL: nil,
                    diff: Self.diff(from: current?.text ?? "", to: "")
                )
            }
        }

        let plan = ManagedMutationPlan(
            id: operationID,
            kind: kind,
            createdAt: .now,
            targets: targets
        )
        try writeJSON(plan, to: operationRoot.appending(path: "plan.json"))
        return plan
        } catch {
            await recordOperation(
                id: operationID,
                kind: kind,
                status: .failed,
                startedAt: startedAt,
                targetURLs: requests.map { $0.destinationURL.standardizedFileURL },
                recoveryURLs: [],
                message: error.localizedDescription
            )
            throw error
        }
    }

    public func execute(_ plan: ManagedMutationPlan) async throws -> ManagedMutationReceipt {
        let startedAt = Date.now
        let operationRoot = recoveryRoot.appending(path: plan.id, directoryHint: .isDirectory)
        let backupRoot = operationRoot.appending(path: "Backups", directoryHint: .isDirectory)
        var journal: RecoveryJournal?

        do {
            try validate(plan)
            try faultInjector?(.validated)
            try fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)

            let journalTargets = try plan.targets.enumerated().map { index, target in
                let existed = fileManager.fileExists(atPath: target.destinationURL.path)
                let backupURL: URL?
                if existed {
                    let proposedName = "\(index)-\(target.destinationURL.lastPathComponent)"
                    let destination = backupRoot.appending(path: proposedName)
                    try fileManager.copyItem(at: target.destinationURL, to: destination)
                    backupURL = destination
                } else {
                    backupURL = nil
                }
                return RecoveryJournalTarget(
                    id: target.id,
                    destinationURL: target.destinationURL,
                    action: target.action,
                    expectedHash: target.expectedHash,
                    proposedHash: target.proposedHash,
                    backupURL: backupURL,
                    existed: existed
                )
            }
            try faultInjector?(.backupsCreated)

            journal = RecoveryJournal(
                operationID: plan.id,
                kind: plan.kind,
                startedAt: startedAt,
                phase: .prepared,
                targets: journalTargets
            )
            try writeJournal(journal, operationRoot: operationRoot)
            try faultInjector?(.journalPrepared)
            journal?.phase = .mutating
            try writeJournal(journal, operationRoot: operationRoot)

            var outcomes = [MutationTargetOutcome]()
            for target in plan.targets {
                try faultInjector?(.beforeTargetMutation)
                let journalTarget = try journalTarget(id: target.id, in: journalTargets)
                switch target.action {
                case .write:
                    guard let stagedURL = target.stagedURL else {
                        throw SkillMutationError.invalidPlan
                    }
                    let proposedData = try Data(contentsOf: stagedURL, options: .mappedIfSafe)
                    try fileManager.createDirectory(
                        at: target.destinationURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try coordinatedWrite(proposedData, to: target.destinationURL)
                    guard rawHash(at: target.destinationURL) == target.proposedHash else {
                        throw SkillMutationError.verificationFailed(target.destinationURL)
                    }
                    outcomes.append(MutationTargetOutcome(
                        id: target.id,
                        destinationURL: target.destinationURL,
                        resultingHash: target.proposedHash,
                        recoveryURL: journalTarget.backupURL
                    ))
                case .remove:
                    try coordinatedRemove(at: target.destinationURL)
                    guard !fileManager.fileExists(atPath: target.destinationURL.path) else {
                        throw SkillMutationError.verificationFailed(target.destinationURL)
                    }
                    outcomes.append(MutationTargetOutcome(
                        id: target.id,
                        destinationURL: target.destinationURL,
                        resultingHash: nil,
                        recoveryURL: journalTarget.backupURL
                    ))
                }
                try faultInjector?(.afterTargetVerification)
            }

            try faultInjector?(.beforeCommit)
            journal?.phase = .committed
            try writeJournal(journal, operationRoot: operationRoot)
            await recordOperation(
                id: plan.id,
                kind: plan.kind,
                status: .committed,
                startedAt: startedAt,
                targetURLs: plan.targets.map(\.destinationURL),
                recoveryURLs: journalTargets.compactMap(\.backupURL),
                message: nil
            )
            return ManagedMutationReceipt(operationID: plan.id, outcomes: outcomes)
        } catch {
            var status = ManagedOperationStatus.failed
            if var journal {
                if rollback(journal.targets) {
                    journal.phase = .rolledBack
                    status = .rolledBack
                } else {
                    journal.phase = .recoveryRequired
                    status = .recoveryRequired
                }
                try? writeJournal(journal, operationRoot: operationRoot)
            }
            await recordOperation(
                id: plan.id,
                kind: plan.kind,
                status: status,
                startedAt: startedAt,
                targetURLs: plan.targets.map(\.destinationURL),
                recoveryURLs: journal?.targets.compactMap(\.backupURL) ?? [],
                message: error.localizedDescription
            )
            throw error
        }
    }

    public func recoverInterruptedOperations() async throws -> [ManagedOperationRecord] {
        guard fileManager.fileExists(atPath: recoveryRoot.path) else { return [] }
        let childURLs = try fileManager.contentsOfDirectory(
            at: recoveryRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var recoveredRecords = [ManagedOperationRecord]()

        for operationRoot in childURLs {
            let journalURL = operationRoot.appending(path: "journal.json")
            guard
                let data = try? Data(contentsOf: journalURL),
                var journal = try? decoder.decode(RecoveryJournal.self, from: data),
                !journal.phase.isTerminal
            else { continue }

            let didRecover = rollback(journal.targets)
            journal.phase = didRecover ? .rolledBack : .recoveryRequired
            try writeJournal(journal, operationRoot: operationRoot)
            let record = ManagedOperationRecord(
                id: journal.operationID,
                kind: journal.kind,
                status: didRecover ? .recovered : .recoveryRequired,
                startedAt: journal.startedAt,
                finishedAt: .now,
                targetURLs: journal.targets.map(\.destinationURL),
                recoveryURLs: journal.targets.compactMap(\.backupURL),
                message: didRecover
                    ? "Spellbook restored this operation after an interrupted launch."
                    : "One or more files changed after interruption and require manual recovery."
            )
            try? await catalog?.recordOperation(record)
            recoveredRecords.append(record)
        }
        return recoveredRecords
    }

    public func restore(
        recoveryURL: URL,
        to destinationURL: URL,
        expectedHash: String?
    ) async throws -> FileMutationReceipt {
        guard
            let data = try? Data(contentsOf: recoveryURL, options: .mappedIfSafe),
            let text = String(data: data, encoding: .utf8)
        else { throw SkillMutationError.unreadable(recoveryURL) }
        let plan = try await plan(
            [MutationRequest(
                destinationURL: destinationURL,
                action: .write,
                expectedHash: expectedHash,
                proposedText: text
            )],
            kind: .restore
        )
        let receipt = try await execute(plan)
        guard let outcome = receipt.outcomes.first else { throw SkillMutationError.invalidPlan }
        return FileMutationReceipt(
            destinationURL: outcome.destinationURL,
            resultingHash: outcome.resultingHash,
            recoveryURL: outcome.recoveryURL
        )
    }

    public func write(
        _ text: String,
        to url: URL,
        expectedHash: String?,
        kind: ManagedOperationKind
    ) async throws -> FileMutationReceipt {
        let plan = try await plan(
            [MutationRequest(
                destinationURL: url,
                action: .write,
                expectedHash: expectedHash,
                proposedText: text
            )],
            kind: kind
        )
        let receipt = try await execute(plan)
        guard let outcome = receipt.outcomes.first else { throw SkillMutationError.invalidPlan }
        return FileMutationReceipt(
            destinationURL: outcome.destinationURL,
            resultingHash: outcome.resultingHash,
            recoveryURL: outcome.recoveryURL
        )
    }

    public func remove(
        at url: URL,
        expectedHash: String
    ) async throws -> FileMutationReceipt {
        let plan = try await plan(
            [MutationRequest(
                destinationURL: url,
                action: .remove,
                expectedHash: expectedHash,
                proposedText: nil
            )],
            kind: .remove
        )
        let receipt = try await execute(plan)
        guard let outcome = receipt.outcomes.first else { throw SkillMutationError.invalidPlan }
        return FileMutationReceipt(
            destinationURL: outcome.destinationURL,
            resultingHash: outcome.resultingHash,
            recoveryURL: outcome.recoveryURL
        )
    }

    public func suggestedEntryURL(for agent: AgentKind, skillName: String) -> URL {
        let root = roots.first(where: { $0.agent == agent })?.url ?? fallbackRoot(for: agent)
        return root
            .appending(path: Self.slug(skillName), directoryHint: .isDirectory)
            .appending(path: "SKILL.md", directoryHint: .notDirectory)
    }

    private func validate(_ plan: ManagedMutationPlan) throws {
        guard !plan.targets.isEmpty else { throw SkillMutationError.invalidPlan }
        for target in plan.targets {
            let current = fileManager.fileExists(atPath: target.destinationURL.path)
                ? try read(at: target.destinationURL)
                : nil
            try validateExpectedHash(
                target.expectedHash,
                current: current,
                destinationURL: target.destinationURL
            )
            switch target.action {
            case .write:
                guard
                    let stagedURL = target.stagedURL,
                    let proposedHash = target.proposedHash,
                    rawHash(at: stagedURL) == proposedHash
                else { throw SkillMutationError.invalidPlan }
            case .remove:
                guard current != nil else {
                    throw SkillMutationError.changedSinceReview(target.destinationURL)
                }
            }
        }
    }

    private func validateExpectedHash(
        _ expectedHash: String?,
        current: ManagedFileContent?,
        destinationURL: URL
    ) throws {
        if let expectedHash {
            guard current?.contentHash == expectedHash else {
                throw SkillMutationError.changedSinceReview(destinationURL)
            }
        } else if current != nil {
            throw SkillMutationError.destinationAlreadyExists(destinationURL)
        }
    }

    private func journalTarget(
        id: String,
        in targets: [RecoveryJournalTarget]
    ) throws -> RecoveryJournalTarget {
        guard let target = targets.first(where: { $0.id == id }) else {
            throw SkillMutationError.invalidPlan
        }
        return target
    }

    private func writeJournal(_ journal: RecoveryJournal?, operationRoot: URL) throws {
        guard let journal else { throw SkillMutationError.invalidPlan }
        try writeJSON(journal, to: operationRoot.appending(path: "journal.json"))
    }

    private func writeJSON<Value: Encodable>(_ value: Value, to url: URL) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private func coordinatedWrite(_ data: Data, to destinationURL: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var writeError: (any Error)?
        coordinator.coordinate(
            writingItemAt: destinationURL,
            options: .forReplacing,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
    }

    private func coordinatedRemove(at destinationURL: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var removalError: (any Error)?
        coordinator.coordinate(
            writingItemAt: destinationURL,
            options: .forDeleting,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try fileManager.removeItem(at: coordinatedURL)
            } catch {
                removalError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let removalError { throw removalError }
    }

    private func rollback(_ targets: [RecoveryJournalTarget]) -> Bool {
        var didRestoreEveryTarget = true
        for target in targets.reversed() {
            do {
                let currentHash = rawHash(at: target.destinationURL)
                if target.existed {
                    if currentHash == target.expectedHash { continue }
                    guard
                        currentHash == nil || currentHash == target.proposedHash,
                        let backupURL = target.backupURL
                    else { throw SkillMutationError.recoveryUnsafe(target.destinationURL) }
                    if fileManager.fileExists(atPath: target.destinationURL.path) {
                        try fileManager.removeItem(at: target.destinationURL)
                    }
                    try fileManager.createDirectory(
                        at: target.destinationURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try fileManager.copyItem(at: backupURL, to: target.destinationURL)
                    guard rawHash(at: target.destinationURL) == target.expectedHash else {
                        throw SkillMutationError.verificationFailed(target.destinationURL)
                    }
                } else {
                    guard currentHash == nil || currentHash == target.proposedHash else {
                        throw SkillMutationError.recoveryUnsafe(target.destinationURL)
                    }
                    if currentHash != nil {
                        try fileManager.removeItem(at: target.destinationURL)
                    }
                }
            } catch {
                didRestoreEveryTarget = false
            }
        }
        return didRestoreEveryTarget
    }

    private func rawHash(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return StableHasher.sha256(data)
    }

    private func fallbackRoot(for agent: AgentKind) -> URL {
        let home = fileManager.homeDirectoryForCurrentUser
        switch agent {
        case .claude:
            return home.appending(path: ".claude/skills", directoryHint: .isDirectory)
        case .cursor:
            return home.appending(path: ".cursor/skills", directoryHint: .isDirectory)
        case .codex:
            return home.appending(path: ".codex/skills", directoryHint: .isDirectory)
        }
    }

    private static func diff(from original: String, to proposed: String) -> MutationDiffSummary {
        let originalLines = original.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let proposedLines = proposed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let difference = proposedLines.difference(from: originalLines)
        var additions = 0
        var removals = 0
        for change in difference {
            switch change {
            case .insert: additions += 1
            case .remove: removals += 1
            }
        }
        return MutationDiffSummary(addedLineCount: additions, removedLineCount: removals)
    }

    private static func slug(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let parts = name.lowercased().unicodeScalars.split { !allowed.contains($0) }
        let result = parts.map(String.init).joined(separator: "-")
        return result.isEmpty ? "untitled-skill" : result
    }

    private static func defaultRecoveryRoot(fileManager: FileManager) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return applicationSupport
            .appending(path: "Spellbook", directoryHint: .isDirectory)
            .appending(path: "Recovery", directoryHint: .isDirectory)
    }

    private func recordOperation(
        id: String,
        kind: ManagedOperationKind,
        status: ManagedOperationStatus,
        startedAt: Date,
        targetURLs: [URL],
        recoveryURLs: [URL],
        message: String?
    ) async {
        let record = ManagedOperationRecord(
            id: id,
            kind: kind,
            status: status,
            startedAt: startedAt,
            finishedAt: .now,
            targetURLs: targetURLs,
            recoveryURLs: recoveryURLs,
            message: message
        )
        try? await catalog?.recordOperation(record)
    }
}
