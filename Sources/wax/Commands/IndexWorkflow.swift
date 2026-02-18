import ArgumentParser
import Foundation

struct IndexResult: Sendable {
    let repoRoot: String
    let indexedCount: Int
    let elapsedSeconds: Double
    let modeLabel: String
}

enum IndexWorkflow {
    static func ensureIndexedIfNeeded(
        repoRoot: String,
        textOnly: Bool,
        maxCommits: Int = 0,
        autoIndex: Bool
    ) async throws -> RepoLayout {
        let layout = repoLayout(for: repoRoot)
        guard !FileManager.default.fileExists(atPath: layout.storePath.path) else {
            return layout
        }

        guard autoIndex else {
            throw ValidationError("No index found. Run `wax index --repo-path \(repoRoot)` first.")
        }

        print("No index found for \(repoRoot). Building initial index...")
        _ = try await run(
            repoRoot: repoRoot,
            full: true,
            maxCommits: maxCommits,
            textOnly: textOnly,
            showProgress: true
        )
        return layout
    }

    static func run(
        repoRoot: String,
        full: Bool,
        maxCommits: Int,
        textOnly: Bool,
        showProgress: Bool
    ) async throws -> IndexResult {
        let layout = repoLayout(for: repoRoot)

        try FileManager.default.createDirectory(at: layout.waxDirectory, withIntermediateDirectories: true)
        ensureGitignore(repoRoot: repoRoot)

        var sinceHash: String?
        if !full,
           let data = try? Data(contentsOf: layout.lastHashFile),
           let hash = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !hash.isEmpty {
            sinceHash = hash
        }

        let modeLabel = sinceHash != nil ? "incremental (since \(sinceHash!.prefix(7)))" : "full"
        print("Indexing \(repoRoot) [\(modeLabel)]...")

        let allCommits = try await GitLogParser.parseLog(
            repoPath: repoRoot,
            maxCount: maxCommits,
            since: sinceHash
        )
        let commits = maxCommits > 0 ? Array(allCommits.prefix(maxCommits)) : allCommits

        guard !commits.isEmpty else {
            print("No new commits to index.")
            return IndexResult(repoRoot: repoRoot, indexedCount: 0, elapsedSeconds: 0, modeLabel: modeLabel)
        }

        print("Found \(commits.count) commit\(commits.count == 1 ? "" : "s") to index.")

        let store = try await RepoStore(storeURL: layout.storePath, textOnly: textOnly)

        let repoName = URL(fileURLWithPath: repoRoot).lastPathComponent
        let start = CFAbsoluteTimeGetCurrent()

        try await store.ingest(commits, repoName: repoName) { indexed, total in
            guard showProgress else { return }
            let pct = Int(Double(indexed) / Double(total) * 100)
            let filled = max(0, min(50, pct / 2))
            let bar = String(repeating: "=", count: filled) + String(repeating: " ", count: 50 - filled)
            print("\r  [\(bar)] \(indexed)/\(total) (\(pct)%)", terminator: "")
            fflush(stdout)
        }

        if showProgress { print() }

        if let latestHash = commits.first?.hash {
            try latestHash.write(to: layout.lastHashFile, atomically: true, encoding: .utf8)
        }

        try await store.close()

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        print("Indexed \(commits.count) commit\(commits.count == 1 ? "" : "s") in \(String(format: "%.1f", elapsed))s")

        return IndexResult(
            repoRoot: repoRoot,
            indexedCount: commits.count,
            elapsedSeconds: elapsed,
            modeLabel: modeLabel
        )
    }
}
