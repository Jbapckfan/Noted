import XCTest
import SwiftData
@testable import NotedCoreKit

final class ShiftBoardTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        ModelContext(try EncounterStore.inMemoryContainer())
    }

    func testSignTwentyFiveMixedEncountersInRandomOrder() throws {
        let ctx = try makeContext()
        let phases: [EncounterPhase] = [
            .noteDrafted, .dischargeDrafted, .transcribing, .signed, .failed,
        ].flatMap { Array(repeating: $0, count: 5) } // 25, mixed

        var signableIDs = Set<UUID>()
        for (i, phase) in phases.enumerated() {
            let e = Encounter(chiefComplaint: "pt-\(i)", phase: phase)
            ctx.insert(e)
            if ShiftBoard.isSignable(e) { signableIDs.insert(e.id) }
        }
        try ctx.save()

        // Sign every signable encounter, in a shuffled order — order must not matter.
        let all = try ShiftBoard.fetchAllForDisplay(in: ctx)
        for e in all.shuffled() where ShiftBoard.isSignable(e) {
            let didSign = try ShiftBoard.sign(e, in: ctx)
            XCTAssertTrue(didSign)
        }

        let after = try ctx.fetch(FetchDescriptor<Encounter>())
        let nowSigned = after.filter { $0.phase == .signed }
        // Originally-signable (10) + the 5 that were already signed = 15 signed total.
        XCTAssertEqual(Set(after.filter { signableIDs.contains($0.id) }.map(\.phase)), [.signed])
        XCTAssertTrue(after.filter { signableIDs.contains($0.id) }.allSatisfy { $0.signedAt != nil })
        XCTAssertEqual(nowSigned.count, signableIDs.count + 5)
    }

    func testNoTenEncounterCap() throws {
        let ctx = try makeContext()
        for i in 0..<25 { ctx.insert(Encounter(chiefComplaint: "e-\(i)", phase: .noteDrafted)) }
        try ctx.save()
        XCTAssertEqual(try ShiftBoard.fetchAllForDisplay(in: ctx).count, 25, "no 10-encounter truncation")
    }

    func testDisplayOrderingPutsAttentionFirstSignedLast() throws {
        let ctx = try makeContext()
        let signed = Encounter(chiefComplaint: "signed", phase: .signed)
        let working = Encounter(chiefComplaint: "working", phase: .transcribing)
        let ready = Encounter(chiefComplaint: "ready", phase: .noteDrafted)
        let failed = Encounter(chiefComplaint: "failed", phase: .failed)
        [signed, working, ready, failed].forEach { ctx.insert($0) }
        try ctx.save()

        let ordered = try ShiftBoard.fetchAllForDisplay(in: ctx)
        // needs-attention (ready, failed) before in-progress (working) before terminal (signed)
        XCTAssertEqual(ordered.last?.chiefComplaint, "signed")
        let readyIdx = ordered.firstIndex { $0.chiefComplaint == "ready" }!
        let workingIdx = ordered.firstIndex { $0.chiefComplaint == "working" }!
        XCTAssertLessThan(readyIdx, workingIdx)
    }

    func testSignRejectsNonSignablePhase() throws {
        let ctx = try makeContext()
        let e = Encounter(chiefComplaint: "x", phase: .transcribing)
        ctx.insert(e)
        try ctx.save()
        XCTAssertFalse(try ShiftBoard.sign(e, in: ctx))
        XCTAssertEqual(e.phase, .transcribing)
        XCTAssertNil(e.signedAt)
    }

    func testStatusBadgeMapping() {
        XCTAssertEqual(ShiftBoard.status(for: .noteDrafted).badge, .readyToSign)
        XCTAssertTrue(ShiftBoard.status(for: .noteDrafted).needsAttention)
        XCTAssertEqual(ShiftBoard.status(for: .signed).badge, .signed)
        XCTAssertFalse(ShiftBoard.status(for: .signed).needsAttention)
        XCTAssertEqual(ShiftBoard.status(for: .failed).badge, .failed)
        XCTAssertEqual(ShiftBoard.status(for: .transcribing).badge, .working)
    }
}
