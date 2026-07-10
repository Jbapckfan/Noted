import Foundation
import NotedCoreKit

// nc-summarize <transcript.txt> <extraction.json>
// Runs the SHIPPING pipeline on an LLM extraction: parse → GroundingVerifier.filtered →
// NoteTemplate, plus the calculator suggestion engine. This is exactly what the device does after
// the model extracts facts, so it faithfully shows what the app would render for a given transcript.

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: nc-summarize <transcript.txt> <extraction.json>\n".utf8))
    exit(2)
}

let transcript = (try? String(contentsOfFile: args[1], encoding: .utf8)) ?? ""
let json = (try? String(contentsOfFile: args[2], encoding: .utf8)) ?? "{}"

do {
    let facts = try ClinicalFacts.parse(json)
    let (grounded, report) = GroundingVerifier(transcript: transcript).filtered(facts)
    let note = NoteTemplate.renderHPIandMDM(grounded, removed: report.flags)

    print("========== GROUNDED NOTE ==========")
    print(note.isEmpty ? "(empty — nothing survived grounding)" : note)

    print("\n========== REMOVED BY GROUNDING (\(report.flags.count)) ==========")
    if report.flags.isEmpty {
        print("(nothing removed — every extracted value was supported by the transcript)")
    } else {
        for f in report.flags { print("- [\(f.kind)] \(f.claim) — \(f.detail)") }
    }

    let suggestions = CalculatorRegistry.suggestions(for: grounded)
    print("\n========== CALCULATOR SUGGESTIONS (\(suggestions.count)) ==========")
    for s in suggestions { print("- \(s.name): \(s.reason)") }
} catch {
    FileHandle.standardError.write(Data("extraction JSON did not parse: \(error)\n".utf8))
    exit(1)
}
