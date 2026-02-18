import ArgumentParser
import Foundation
import SwiftTUI

struct TUICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tui",
        abstract: "Launch interactive semantic git search UI"
    )

    @OptionGroup var options: GlobalOptions

    mutating func run() async throws {
        let repoRoot = try resolveRepoRoot(options.repoPath)
        let layout = try await IndexWorkflow.ensureIndexedIfNeeded(
            repoRoot: repoRoot,
            textOnly: options.textOnly,
            maxCommits: options.maxCommits,
            autoIndex: !options.noAutoIndex
        )

        let store = try await RepoStore(storeURL: layout.storePath, textOnly: options.textOnly)
        // SwiftTUI's Application.start() calls dispatch_main(), which must execute on main thread.
        await MainActor.run {
            let viewModel = SearchViewModel(store: store, topK: options.topK)
            Application(rootView: SearchView(viewModel: viewModel)).start()
        }
    }
}
