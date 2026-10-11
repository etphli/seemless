import Testing
import Foundation
@testable import SeemlessCore

struct HistoryRepositoryTests {
    @Test
    func testExpiryDeletesImagesAndPreservesPinnedItems() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = HistoryRepository(root: root)
        let now = Date()
        let old = now.addingTimeInterval(-HistoryPolicy.retention - 1)
        let image = ClipboardEntry(fingerprint: "image", payload: .image(fileName: "old.png", width: 1, height: 1), copiedAt: old, sourceName: "Test")
        _ = try await repository.insert(image, imageData: Data([1, 2, 3]), now: old)
        let pin = ClipboardEntry(fingerprint: "pin", payload: .text("Keep me"), copiedAt: old, isPinned: true, sourceName: "Test")
        _ = try await repository.insert(pin, now: old)
        let fresh = ClipboardEntry(fingerprint: "fresh", payload: .link("https://example.com"), copiedAt: now, sourceName: "Test")
        _ = try await repository.insert(fresh, now: now)
        let retained = try await repository.load(now: now)
        #expect(Set(retained.map(\.id)) == Set([pin.id, fresh.id]))
        #expect(!(FileManager.default.fileExists(atPath: root.appendingPathComponent("images/old.png").path)))
        let reloaded = try await HistoryRepository(root: root).load(now: now)
        #expect(retained == reloaded)
    }

    @Test
    func testDuplicateCopyKeepsPinAndIdentityAndRefreshesExpiry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = HistoryRepository(root: root)
        let original = ClipboardEntry(fingerprint: "same", payload: .text("hello"), copiedAt: Date().addingTimeInterval(-500), isPinned: true, sourceName: "First")
        _ = try await repository.insert(original)
        let repeated = ClipboardEntry(fingerprint: "same", payload: .text("hello"), sourceName: "Second")
        let entries = try await repository.insert(repeated)
        #expect(entries.count == 1)
        #expect(entries[0].id == original.id)
        #expect(entries[0].isPinned)
        #expect(entries[0].copiedAt == repeated.copiedAt)
        #expect(entries[0].sourceName == "Second")
    }

    @Test
    func testClearingUnpinnedAndDeletingPinnedCleanTheIndex() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = HistoryRepository(root: root)
        let pin = ClipboardEntry(fingerprint: "pin", payload: .image(fileName: "pin.png", width: 1, height: 1), isPinned: true, sourceName: "Test")
        _ = try await repository.insert(pin, imageData: Data([1]))
        _ = try await repository.insert(ClipboardEntry(fingerprint: "text", payload: .text("clear"), sourceName: "Test"))
        let cleared = try await repository.clearUnpinned()
        #expect(cleared.map(\.id) == [pin.id])
        let removed = try await repository.remove(pin.id)
        #expect(removed.isEmpty)
        #expect(!(FileManager.default.fileExists(atPath: root.appendingPathComponent("images/pin.png").path)))
    }

    @Test
    func testImagePathCannotEscapeRepository() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = HistoryRepository(root: root)
        let entry = ClipboardEntry(fingerprint: "invalid", payload: .image(fileName: "../escape.png", width: 1, height: 1), sourceName: "Test")
        do {
            _ = try await repository.insert(entry, imageData: Data([1]))
            Issue.record("Path traversal should be rejected")
        } catch { #expect(error is HistoryError) }
    }

    @Test
    func testRetentionBoundaryAndUnpinningExpiredItem() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date()
        let boundary = ClipboardEntry(fingerprint: "boundary", payload: .text("text"), copiedAt: now.addingTimeInterval(-HistoryPolicy.retention), sourceName: "Test")
        #expect(HistoryPolicy.retaining([boundary], now: now).isEmpty)
        let pinned = ClipboardEntry(fingerprint: "pin", payload: .text("text"), copiedAt: boundary.copiedAt, isPinned: true, sourceName: "Test")
        let repository = HistoryRepository(root: root)
        _ = try await repository.insert(pinned, now: now)
        let unpinned = try await repository.togglePin(pinned.id, now: now)
        #expect(unpinned.isEmpty)
    }

    @Test
    func testConcurrentWritesDoNotLoseHistoryEntries() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = HistoryRepository(root: root)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<40 {
                group.addTask {
                    _ = try await repository.insert(ClipboardEntry(fingerprint: "\(index)", payload: .text("\(index)"), sourceName: "Test"))
                }
            }
            try await group.waitForAll()
        }
        let entries = try await HistoryRepository(root: root).load()
        #expect(entries.count == 40)
        #expect(Set(entries.map(\.fingerprint)) == Set((0..<40).map(String.init)))
    }
}
