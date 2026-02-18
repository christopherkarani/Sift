import Foundation
import Wax

#if MiniLMEmbeddings && canImport(WaxVectorSearchMiniLM)
import CoreML
import WaxVectorSearchMiniLM
#endif

struct CommitSearchResult: Sendable {
    let hash: String
    let shortHash: String
    let author: String
    let date: String
    let subject: String
    let score: Float
    let previewText: String
}

struct StoreStats: Sendable {
    let frameCount: UInt64
    let storeURL: URL
}

actor RepoStore {
    private let wax: Wax
    private let session: WaxSession
    private let storeURL: URL
    private let embedder: (any EmbeddingProvider)?

    private static let headerPrefix = "COMMIT:"

    init(storeURL: URL, textOnly: Bool = false) async throws {
        self.storeURL = storeURL

        if FileManager.default.fileExists(atPath: storeURL.path) {
            self.wax = try await Wax.open(at: storeURL)
        } else {
            self.wax = try await Wax.create(at: storeURL)
        }

        let localEmbedder: (any EmbeddingProvider)? = {
            guard !textOnly else { return nil }
            #if MiniLMEmbeddings && canImport(WaxVectorSearchMiniLM)
            // Keep CLI defaults reliability-first.
            let modelConfiguration = MLModelConfiguration()
            modelConfiguration.computeUnits = .cpuOnly
            let config = MiniLMEmbedder.Config(batchSize: 1, modelConfiguration: modelConfiguration)
            if let embedder = try? MiniLMEmbedder(config: config) {
                return embedder
            }
            return nil
            #else
            return nil
            #endif
        }()
        self.embedder = localEmbedder

        let sessionConfig = WaxSession.Config(
            enableTextSearch: true,
            enableVectorSearch: localEmbedder != nil,
            enableStructuredMemory: false,
            vectorEnginePreference: .cpuOnly,
            vectorMetric: .cosine,
            vectorDimensions: localEmbedder?.dimensions
        )
        self.session = try await wax.openSession(.readWrite(.wait), config: sessionConfig)

        #if MiniLMEmbeddings && canImport(WaxVectorSearchMiniLM)
        if let embedder = localEmbedder as? MiniLMEmbedder {
            try? await embedder.prewarm(batchSize: 1)
        }
        #endif
    }

    func ingest(
        _ commits: [GitCommit],
        repoName: String,
        progress: @Sendable (Int, Int) -> Void
    ) async throws {
        let total = commits.count

        for (index, commit) in commits.enumerated() {
            let metadata = CommitFrameMapper.metadata(for: commit, repoName: repoName)
            let content = Self.formatContent(for: commit)
            let frameOptions = FrameMetaSubset(role: .document, metadata: Metadata(metadata))

            let frameId: UInt64
            if let embedder {
                let vector = try await embedder.embed(content)
                frameId = try await session.put(
                    Data(content.utf8),
                    embedding: vector,
                    identity: embedder.identity,
                    options: frameOptions
                )
            } else {
                frameId = try await session.put(Data(content.utf8), options: frameOptions)
            }

            try await session.indexText(frameId: frameId, text: content)
            progress(index + 1, total)
        }

        try await session.commit()
    }

    func search(query: String, topK: Int = 10) async throws -> [CommitSearchResult] {
        let request: SearchRequest
        if let embedder {
            let embedding = try await embedder.embed(query)
            request = SearchRequest(
                query: query,
                embedding: embedding,
                vectorEnginePreference: .cpuOnly,
                mode: .hybrid(alpha: 0.4),
                topK: topK,
                previewMaxBytes: 2048
            )
        } else {
            request = SearchRequest(
                query: query,
                embedding: nil,
                vectorEnginePreference: .cpuOnly,
                mode: .textOnly,
                topK: topK,
                previewMaxBytes: 2048
            )
        }

        let response = try await session.search(request)
        guard !response.results.isEmpty else { return [] }

        var parsed: [CommitSearchResult] = []
        parsed.reserveCapacity(response.results.count)

        for result in response.results {
            let preview = try await loadPreview(for: result)
            if let item = Self.parseResult(from: preview, score: result.score) {
                parsed.append(item)
            }
        }

        return parsed
    }

    func stats() async -> StoreStats {
        let runtime = await wax.stats()
        return StoreStats(frameCount: runtime.frameCount, storeURL: storeURL)
    }

    func close() async throws {
        await session.close()
        try await wax.close()
    }

    private func loadPreview(for result: SearchResponse.Result) async throws -> String {
        if let fullData = try? await wax.frameContent(frameId: result.frameId),
           let fullText = String(data: fullData, encoding: .utf8),
           !fullText.isEmpty {
            return fullText
        }

        if let previewText = result.previewText, !previewText.isEmpty {
            return previewText
        }

        let previewData = try await wax.framePreview(frameId: result.frameId, maxBytes: 4096)
        return String(data: previewData, encoding: .utf8) ?? ""
    }

    private static func formatContent(for commit: GitCommit) -> String {
        let header = "\(headerPrefix)\(commit.hash)|\(commit.shortHash)|\(commit.author)|\(commit.date)|\(commit.subject)"
        return header + "\n" + commit.ingestContent
    }

    private static func parseResult(from preview: String, score: Float) -> CommitSearchResult? {
        guard preview.hasPrefix(headerPrefix) else {
            return CommitSearchResult(
                hash: "",
                shortHash: "",
                author: "",
                date: "",
                subject: preview.components(separatedBy: "\n").first ?? preview,
                score: score,
                previewText: preview
            )
        }

        let firstNewline = preview.firstIndex(of: "\n") ?? preview.endIndex
        let headerLine = String(preview[preview.index(preview.startIndex, offsetBy: headerPrefix.count)..<firstNewline])
        let parts = headerLine.components(separatedBy: "|")

        guard parts.count >= 5 else {
            return CommitSearchResult(
                hash: "",
                shortHash: "",
                author: "",
                date: "",
                subject: preview,
                score: score,
                previewText: preview
            )
        }

        let remainingText = firstNewline < preview.endIndex
            ? String(preview[preview.index(after: firstNewline)...])
            : ""

        return CommitSearchResult(
            hash: parts[0],
            shortHash: parts[1],
            author: parts[2],
            date: parts[3],
            subject: parts[4..<parts.count].joined(separator: "|"),
            score: score,
            previewText: remainingText
        )
    }
}
