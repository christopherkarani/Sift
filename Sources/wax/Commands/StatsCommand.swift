import ArgumentParser
import Foundation

struct StatsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Show index statistics"
    )

    @Option(name: .customLong("repo-path"), help: "Path to the git repository (default: current directory)")
    var repoPath: String = "."

    mutating func run() async throws {
        let repoRoot = try resolveRepoRoot(repoPath)
        let layout = repoLayout(for: repoRoot)

        guard FileManager.default.fileExists(atPath: layout.storePath.path) else {
            print("No index found. Run `wax index --repo-path \(repoRoot)` first.")
            return
        }

        let store = try await RepoStore(storeURL: layout.storePath, textOnly: true)
        let stats = await store.stats()

        let lastHash: String? = {
            guard let data = try? Data(contentsOf: layout.lastHashFile),
                  let hash = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !hash.isEmpty else {
                return nil
            }
            return hash
        }()

        let fileSize: String = {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: layout.storePath.path),
                  let bytes = attrs[.size] as? Int64 else {
                return "unknown"
            }
            return formatBytes(bytes)
        }()

        print("wax index stats")
        print("─────────────────────")
        print("  Repository:    \(repoRoot)")
        print("  Frames:        \(stats.frameCount)")
        print("  Store size:    \(fileSize)")
        if let lastHash {
            print("  Last indexed:  \(lastHash.prefix(12))")
        }

        try await store.close()
    }
}
