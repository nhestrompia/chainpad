import CryptoScratchpadKit
import Foundation
import Testing

@Suite(.serialized)
@MainActor
struct RepositoryTests {
    private func makeRepository() -> InMemoryScratchpadRepository {
        InMemoryScratchpadRepository()
    }

    @Test
    func deduplicatesByKeyWithoutChangingOrderTimestamp() throws {
        let repository = makeRepository()
        let now = Date()

        let event = ClipboardEvent(
            text: "0x1234567890abcdef1234567890abcdef12345678",
            sourceAppBundleID: "com.apple.Safari",
            sourceAppName: "Safari",
            sourcePageURL: nil,
            capturedAt: now
        )

        let detection = DetectionResult(
            rawValue: event.text,
            normalizedValue: event.text.lowercased(),
            kind: .evmAddress,
            type: .wallet,
            chainHint: .ethereum
        )

        let validation = ValidationResult(isValid: true, type: .wallet, chain: .ethereum)
        _ = try repository.upsert(event: event, detection: detection, validation: validation, defaultActions: [])

        let secondEvent = ClipboardEvent(
            text: event.text,
            sourceAppBundleID: "com.apple.Safari",
            sourceAppName: "Safari",
            sourcePageURL: nil,
            capturedAt: now.addingTimeInterval(20)
        )

        let object = try repository.upsert(event: secondEvent, detection: detection, validation: validation, defaultActions: [])

        let session = try repository.fetchSession()
        #expect(session.count == 1)
        #expect(object.hitCount == 2)
        #expect(session.first?.lastSeenAt == event.capturedAt)
    }

    @Test
    func clearsOnlyExpiredNonPinnedObjects() throws {
        let repository = makeRepository()
        let now = Date()

        let oldWallet = DetectionResult(
            rawValue: "0x1234567890abcdef1234567890abcdef12345678",
            normalizedValue: "0x1234567890abcdef1234567890abcdef12345678",
            kind: .evmAddress,
            type: .wallet,
            chainHint: .ethereum
        )

        let oldEvent = ClipboardEvent(
            text: oldWallet.rawValue,
            sourceAppBundleID: nil,
            sourceAppName: nil,
            sourcePageURL: nil,
            capturedAt: now.addingTimeInterval(-10_000)
        )

        let oldObject = try repository.upsert(
            event: oldEvent,
            detection: oldWallet,
            validation: ValidationResult(isValid: true, type: .wallet, chain: .ethereum),
            defaultActions: []
        )

        let freshWallet = DetectionResult(
            rawValue: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            normalizedValue: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            kind: .evmAddress,
            type: .wallet,
            chainHint: .ethereum
        )

        _ = try repository.upsert(
            event: ClipboardEvent(
                text: freshWallet.rawValue,
                sourceAppBundleID: nil,
                sourceAppName: nil,
                sourcePageURL: nil,
                capturedAt: now
            ),
            detection: freshWallet,
            validation: ValidationResult(isValid: true, type: .wallet, chain: .ethereum),
            defaultActions: []
        )

        try repository.pin(oldObject)
        try repository.clearExpired(before: now.addingTimeInterval(-3_600))

        let pinned = try repository.fetchPinned()
        let session = try repository.fetchSession()
        #expect(pinned.count == 1)
        #expect(session.count == 1)
    }

    @Test
    func upgradesExistingValueToNewTypeWithoutCreatingDuplicateRow() throws {
        let repository = makeRepository()
        let value = "CjTHuBrTkn111111111111111111111111111742v"
        let now = Date()

        let event = ClipboardEvent(
            text: value,
            sourceAppBundleID: "com.google.Chrome",
            sourceAppName: "Google Chrome",
            sourcePageURL: nil,
            capturedAt: now
        )

        let detection = DetectionResult(
            rawValue: value,
            normalizedValue: value,
            kind: .solanaAddress,
            type: .wallet,
            chainHint: .solana
        )

        _ = try repository.upsert(
            event: event,
            detection: detection,
            validation: ValidationResult(isValid: true, type: .wallet, chain: .solana),
            defaultActions: []
        )

        let upgraded = try repository.upsert(
            event: event,
            detection: detection,
            validation: ValidationResult(isValid: true, type: .token, chain: .solana),
            defaultActions: []
        )

        let session = try repository.fetchSession()
        #expect(session.count == 1)
        #expect(upgraded.type == .token)
    }
}
