import ArgumentParser

struct GlobalOptions: ParsableArguments {
    @Option(name: .customLong("repo-path"), help: "Path to the git repository (default: current directory)")
    var repoPath: String = "."

    @Option(name: .customLong("top-k"), help: "Maximum number of search results")
    var topK: Int = 10

    @Flag(name: .customLong("text-only"), help: "Use text search only (skip MiniLM embeddings)")
    var textOnly: Bool = false

    @Flag(name: .customLong("no-auto-index"), help: "Do not auto-create an index when one is missing")
    var noAutoIndex: Bool = false

    @Option(name: .customLong("max-commits"), help: "Maximum commits when auto-indexing (0 = unlimited)")
    var maxCommits: Int = 0
}
