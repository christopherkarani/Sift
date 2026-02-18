import ArgumentParser
import Dispatch
import Foundation

struct RepoLayout {
    let rootPath: String
    let waxDirectory: URL
    let storePath: URL
    let lastHashFile: URL
}

func resolveRepoRoot(_ path: String) throws -> String {
    let expanded = (path as NSString).expandingTildeInPath
    let absolutePath = expanded.hasPrefix("/")
        ? expanded
        : FileManager.default.currentDirectoryPath + "/" + expanded

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["rev-parse", "--show-toplevel"]
    process.currentDirectoryURL = URL(fileURLWithPath: absolutePath)

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw ValidationError("Not a git repository: \(absolutePath)")
    }

    guard let root = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
          !root.isEmpty else {
        throw ValidationError("Could not determine git repository root")
    }

    return root
}

func repoLayout(for repoRoot: String) -> RepoLayout {
    let waxDirectory = URL(fileURLWithPath: repoRoot).appendingPathComponent(".wax-repo")
    return RepoLayout(
        rootPath: repoRoot,
        waxDirectory: waxDirectory,
        storePath: waxDirectory.appendingPathComponent("store.mv2s"),
        lastHashFile: waxDirectory.appendingPathComponent("last-indexed-hash")
    )
}

func ensureGitignore(repoRoot: String) {
    let gitignorePath = URL(fileURLWithPath: repoRoot).appendingPathComponent(".gitignore")
    let entry = ".wax-repo/"

    if let contents = try? String(contentsOf: gitignorePath, encoding: .utf8) {
        let lines = contents.components(separatedBy: .newlines)
        if lines.contains(where: { $0.trimmingCharacters(in: .whitespaces) == entry }) {
            return
        }

        let separator = contents.hasSuffix("\n") ? "" : "\n"
        let updated = contents + separator + entry + "\n"
        try? updated.write(to: gitignorePath, atomically: true, encoding: .utf8)
        return
    }

    try? (entry + "\n").write(to: gitignorePath, atomically: true, encoding: .utf8)
}

func writeStderr(_ message: String) {
    guard let data = (message + "\n").data(using: .utf8) else { return }
    FileHandle.standardError.write(data)
}

func formatBytes(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB"]
    var value = Double(bytes)
    var unitIndex = 0
    while value >= 1024 && unitIndex < units.count - 1 {
        value /= 1024
        unitIndex += 1
    }
    if unitIndex == 0 {
        return "\(bytes) B"
    }
    return String(format: "%.1f %@", value, units[unitIndex])
}

private final class AsyncResultBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Value, Error>?

    func set(_ newValue: Result<Value, Error>) {
        lock.lock()
        result = newValue
        lock.unlock()
    }

    func get() -> Result<Value, Error>? {
        lock.lock()
        let value = result
        lock.unlock()
        return value
    }
}

func runAsyncAndBlock<T: Sendable>(
    _ operation: @escaping @Sendable () async throws -> T
) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    let box = AsyncResultBox<T>()

    Task.detached {
        defer { semaphore.signal() }
        do {
            box.set(.success(try await operation()))
        } catch {
            box.set(.failure(error))
        }
    }

    semaphore.wait()
    guard let result = box.get() else {
        throw ValidationError("Operation did not produce a result")
    }
    return try result.get()
}
