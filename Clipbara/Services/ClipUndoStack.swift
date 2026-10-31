import CryptoKit
import Foundation
import SwiftData

/// Deletes clips and pinboard entries in a way ⌘Z can put back (#45).
///
/// Each deletion keeps a value snapshot, so undoing recreates the clip with
/// its original id and copy date (which puts it back in its place in the
/// history) and its pinboard entries in their original positions.
@MainActor
final class ClipUndoStack {
    private struct ClipSnapshot {
        let id: UUID
        let contentTypeRaw: String
        let rawData: Data
        let textContent: String?
        let thumbnailData: Data?
        let sourceAppName: String?
        let sourceAppBundleId: String?
        let contentHash: String
        let copiedAt: Date
        let userTitle: String?
        let isPinned: Bool
    }

    private struct EntrySnapshot {
        let id: UUID
        let clipID: UUID
        let pinboardID: UUID
        let displayOrder: Int
        let addedAt: Date
    }

    private enum Record {
        case clip(ClipSnapshot, entries: [EntrySnapshot])
        case entry(EntrySnapshot)
        /// `added` is the entry created in the destination, nil when the clip
        /// was already there.
        case move(EntrySnapshot, added: UUID?, destinationID: UUID)
        case edit(clipID: UUID, text: String?, rawData: Data, contentHash: String)
        /// Several deletions undone together.
        case batch([Record])
    }

    private static let limit = 20
    private var records: [Record] = []

    var canUndo: Bool { !records.isEmpty }

    /// Deletes the clip from history together with its pinboard entries.
    func deleteClip(_ item: ClipboardItem, in context: ModelContext) {
        push(removeClip(item, in: context))
    }

    /// Deletes several clips; one ⌘Z brings them all back.
    func deleteClips(_ items: [ClipboardItem], in context: ModelContext) {
        push(.batch(items.map { removeClip($0, in: context) }))
    }

    private func removeClip(_ item: ClipboardItem, in context: ModelContext) -> Record {
        let itemID = item.id
        let descriptor = FetchDescriptor<PinboardEntry>(
            predicate: #Predicate { $0.clipboardItem?.id == itemID }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        let entrySnapshots = entries.compactMap(Self.snapshot(of:))
        let record = Record.clip(Self.snapshot(of: item), entries: entrySnapshots)

        let pinboards = Set(entries.compactMap { $0.pinboard?.id })
        entries.forEach(context.delete)
        context.delete(item)
        try? context.save()
        pinboards.forEach { renumber(pinboardID: $0, in: context) }
        return record
    }

    /// Removes the clip from one pinboard only; the clip stays in history.
    func removeEntry(_ entry: PinboardEntry, in context: ModelContext) {
        if let record = detach(entry, in: context) { push(record) }
    }

    /// Removes several entries; one ⌘Z puts them all back.
    func removeEntries(_ entries: [PinboardEntry], in context: ModelContext) {
        let records = entries.compactMap { detach($0, in: context) }
        if !records.isEmpty { push(.batch(records)) }
    }

    private func detach(_ entry: PinboardEntry, in context: ModelContext) -> Record? {
        guard let snapshot = Self.snapshot(of: entry) else { return nil }
        context.delete(entry)
        try? context.save()
        renumber(pinboardID: snapshot.pinboardID, in: context)
        return .entry(snapshot)
    }

    /// Moves a clip from its pinboard to another one. When the destination
    /// already has the clip, this only removes it from the source.
    func moveEntry(_ entry: PinboardEntry, to destination: Pinboard, in context: ModelContext) {
        guard let snapshot = Self.snapshot(of: entry), let item = entry.clipboardItem,
              snapshot.pinboardID != destination.id else { return }
        var addedID: UUID?
        let alreadyThere = destination.entries.contains { !$0.isDeleted && $0.clipboardItem?.id == snapshot.clipID }
        if !alreadyThere {
            let nextOrder = (destination.entries.filter { !$0.isDeleted }.map(\.displayOrder).max() ?? -1) + 1
            let added = PinboardEntry(clipboardItem: item, pinboard: destination, displayOrder: nextOrder)
            context.insert(added)
            addedID = added.id
        }
        push(.move(snapshot, added: addedID, destinationID: destination.id))
        context.delete(entry)
        try? context.save()
        renumber(pinboardID: snapshot.pinboardID, in: context)
    }

    /// Replaces a plain text clip's content (#54). The clip keeps its id,
    /// copy date and pinboard places, so the edit shows everywhere it is.
    func editText(of item: ClipboardItem, to text: String, in context: ModelContext) {
        push(.edit(clipID: item.id, text: item.textContent, rawData: item.rawData, contentHash: item.contentHash))
        let data = Data(text.utf8)
        item.textContent = text
        item.rawData = data
        item.contentHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try? context.save()
    }

    /// Restores the most recent deletion. Returns false when there is nothing
    /// to restore or it can no longer be restored.
    @discardableResult
    func undo(in context: ModelContext) -> Bool {
        guard let record = records.popLast() else { return false }
        return restore(record, in: context)
    }

    private func restore(_ record: Record, in context: ModelContext) -> Bool {
        switch record {
        case .batch(let records):
            // Newest first, so entries return to the positions they left.
            return records.reversed().reduce(true) { restore($1, in: context) && $0 }

        case .clip(let clip, let entries):
            let item = ClipboardItem(
                contentType: ContentType(rawValue: clip.contentTypeRaw) ?? .unknown,
                rawData: clip.rawData,
                textContent: clip.textContent,
                thumbnailData: clip.thumbnailData,
                sourceAppName: clip.sourceAppName,
                sourceAppBundleId: clip.sourceAppBundleId,
                contentHash: clip.contentHash
            )
            item.id = clip.id
            item.copiedAt = clip.copiedAt
            item.userTitle = clip.userTitle
            item.isPinned = clip.isPinned
            context.insert(item)
            for entry in entries {
                restore(entry, item: item, in: context)
            }
            try? context.save()
            return true

        case .move(let entry, let addedID, let destinationID):
            if let addedID {
                var descriptor = FetchDescriptor<PinboardEntry>(predicate: #Predicate { $0.id == addedID })
                descriptor.fetchLimit = 1
                if let added = try? context.fetch(descriptor).first {
                    context.delete(added)
                }
            }
            let clipID = entry.clipID
            var descriptor = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == clipID })
            descriptor.fetchLimit = 1
            guard let item = try? context.fetch(descriptor).first else { return false }
            let restored = restore(entry, item: item, in: context)
            try? context.save()
            renumber(pinboardID: destinationID, in: context)
            return restored

        case .edit(let clipID, let text, let rawData, let contentHash):
            var descriptor = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == clipID })
            descriptor.fetchLimit = 1
            guard let item = try? context.fetch(descriptor).first else { return false }
            item.textContent = text
            item.rawData = rawData
            item.contentHash = contentHash
            try? context.save()
            return true

        case .entry(let entry):
            let clipID = entry.clipID
            var descriptor = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == clipID })
            descriptor.fetchLimit = 1
            guard let item = try? context.fetch(descriptor).first else { return false }
            let restored = restore(entry, item: item, in: context)
            try? context.save()
            return restored
        }
    }

    // MARK: - Helpers

    private func push(_ record: Record) {
        records.append(record)
        if records.count > Self.limit {
            records.removeFirst(records.count - Self.limit)
        }
    }

    /// Puts an entry back at its old position, moving later entries down.
    @discardableResult
    private func restore(_ snapshot: EntrySnapshot, item: ClipboardItem, in context: ModelContext) -> Bool {
        let pinboardID = snapshot.pinboardID
        var descriptor = FetchDescriptor<Pinboard>(predicate: #Predicate { $0.id == pinboardID })
        descriptor.fetchLimit = 1
        guard let pinboard = try? context.fetch(descriptor).first else { return false }
        for other in pinboard.entries where other.displayOrder >= snapshot.displayOrder {
            other.displayOrder += 1
        }
        let entry = PinboardEntry(clipboardItem: item, pinboard: pinboard, displayOrder: snapshot.displayOrder)
        entry.id = snapshot.id
        entry.addedAt = snapshot.addedAt
        context.insert(entry)
        return true
    }

    /// Keeps a pinboard's order contiguous after a removal.
    private func renumber(pinboardID: UUID, in context: ModelContext) {
        var descriptor = FetchDescriptor<Pinboard>(predicate: #Predicate { $0.id == pinboardID })
        descriptor.fetchLimit = 1
        guard let pinboard = try? context.fetch(descriptor).first else { return }
        let ordered = pinboard.entries
            .filter { !$0.isDeleted }
            .sorted { $0.displayOrder < $1.displayOrder }
        for (index, entry) in ordered.enumerated() where entry.displayOrder != index {
            entry.displayOrder = index
        }
        try? context.save()
    }

    private static func snapshot(of item: ClipboardItem) -> ClipSnapshot {
        ClipSnapshot(
            id: item.id,
            contentTypeRaw: item.contentTypeRaw,
            rawData: item.rawData,
            textContent: item.textContent,
            thumbnailData: item.thumbnailData,
            sourceAppName: item.sourceAppName,
            sourceAppBundleId: item.sourceAppBundleId,
            contentHash: item.contentHash,
            copiedAt: item.copiedAt,
            userTitle: item.userTitle,
            isPinned: item.isPinned
        )
    }

    private static func snapshot(of entry: PinboardEntry) -> EntrySnapshot? {
        guard let clipID = entry.clipboardItem?.id, let pinboardID = entry.pinboard?.id else { return nil }
        return EntrySnapshot(
            id: entry.id,
            clipID: clipID,
            pinboardID: pinboardID,
            displayOrder: entry.displayOrder,
            addedAt: entry.addedAt
        )
    }
}

