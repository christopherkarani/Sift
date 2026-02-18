import ArgumentParser
import Foundation
import SwiftTUI

struct TUICommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tui",
        abstract: "Launch interactive semantic git search UI"
    )

    @OptionGroup var options: GlobalOptions

    mutating func run() throws {
        let repoPath = options.repoPath
        let textOnly = options.textOnly
        let maxCommits = options.maxCommits
        let autoIndex = !options.noAutoIndex
        let topK = options.topK

        let repoRoot = try resolveRepoRoot(repoPath)
        let store: RepoStore = try runAsyncAndBlock {
            let layout = try await IndexWorkflow.ensureIndexedIfNeeded(
                repoRoot: repoRoot,
                textOnly: textOnly,
                maxCommits: maxCommits,
                autoIndex: autoIndex
            )
            return try await RepoStore(storeURL: layout.storePath, textOnly: textOnly)
        }

        let viewModel = SearchViewModel(store: store, topK: topK)
        Application(rootView: SearchView(viewModel: viewModel)).start()
    }
}
