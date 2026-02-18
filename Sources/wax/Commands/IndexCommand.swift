import ArgumentParser
import Foundation

struct IndexCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "index",
        abstract: "Index git history for semantic search"
    )

    @Option(name: .customLong("repo-path"), help: "Path to the git repository (default: current directory)")
    var repoPath: String = "."

    @Flag(name: .customLong("full"), help: "Re-index from scratch, ignoring previous progress")
    var full: Bool = false

    @Option(name: .customLong("max-commits"), help: "Maximum number of commits to index (0 = unlimited)")
    var maxCommits: Int = 0

    @Flag(name: .customLong("text-only"), help: "Use text search only (skip MiniLM embeddings)")
    var textOnly: Bool = false

    mutating func run() throws {
        let repoPath = repoPath
        let full = full
        let maxCommits = maxCommits
        let textOnly = textOnly

        let root = try resolveRepoRoot(repoPath)
        _ = try runAsyncAndBlock {
            try await IndexWorkflow.run(
                repoRoot: root,
                full: full,
                maxCommits: maxCommits,
                textOnly: textOnly,
                showProgress: true
            )
        }
    }
}
