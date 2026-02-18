import ArgumentParser
import Foundation

@main
struct WaxCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wax",
        abstract: "Sift semantic git history CLI",
        discussion: "Run `wax tui` for interactive mode, or ask directly: `wax when did we add notifications`.",
        subcommands: [TUICommand.self, IndexCommand.self, StatsCommand.self, QueryCommand.self],
        defaultSubcommand: QueryCommand.self
    )
}

struct QueryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "Run a one-shot natural-language semantic git query"
    )

    @OptionGroup var options: GlobalOptions

    @Argument(parsing: .remaining, help: "Natural-language query.")
    var queryParts: [String] = []

    mutating func run() throws {
        let query = normalizeQuery(queryParts)
        if query.isEmpty {
            var tui = TUICommand()
            tui.options = options
            try tui.run()
            return
        }

        let repoPath = options.repoPath
        let textOnly = options.textOnly
        let maxCommits = options.maxCommits
        let autoIndex = !options.noAutoIndex
        let topK = max(1, options.topK)
        let repoRoot = try resolveRepoRoot(repoPath)
        let layout = try runAsyncAndBlock {
            try await IndexWorkflow.ensureIndexedIfNeeded(
                repoRoot: repoRoot,
                textOnly: textOnly,
                maxCommits: maxCommits,
                autoIndex: autoIndex
            )
        }

        let store = try runAsyncAndBlock {
            try await RepoStore(storeURL: layout.storePath, textOnly: textOnly)
        }
        let start = CFAbsoluteTimeGetCurrent()
        let hits = try runAsyncAndBlock {
            try await store.search(query: query, topK: topK)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        try runAsyncAndBlock {
            try await store.close()
        }

        print("Query: \(query)")
        print("Results: \(hits.count) in \(String(format: "%.1f", elapsed * 1000))ms")

        if hits.isEmpty {
            print("No matches found. Try a broader query or run `wax tui`.")
            return
        }

        for (index, hit) in hits.enumerated() {
            let score = String(format: "%.3f", hit.score)
            print("\n\(index + 1). [\(hit.shortHash)] \(hit.subject)")
            print("   Author: \(hit.author)  Date: \(hit.date)  Score: \(score)")
            let preview = summarizePreview(hit.previewText)
            if !preview.isEmpty {
                print("   \(preview)")
            }
        }
    }
}

func normalizeQuery(_ parts: [String]) -> String {
    parts
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func summarizePreview(_ text: String, maxLines: Int = 2, maxCharsPerLine: Int = 120) -> String {
    let lines = text
        .split(separator: "\n", omittingEmptySubsequences: true)
        .prefix(maxLines)
        .map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.count <= maxCharsPerLine { return trimmed }
            return String(trimmed.prefix(maxCharsPerLine - 1)) + "…"
        }

    return lines.joined(separator: "\n   ")
}
