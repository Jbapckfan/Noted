import Foundation
import SwiftUI

// MARK: - Export Service
// Handles exporting medical notes to various formats

class ExportService {
    
    // MARK: - HTML Export
    
    static func exportToHTML(
        note: String,
        noteType: NoteType,
        segments: [EnhancedTranscriptionSegment]? = nil,
        metadata: EncounterMetadata? = nil
    ) -> String {
        
        let css = """
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 800px;
                margin: 0 auto;
                padding: 20px;
                background: #f5f5f5;
            }
            .header {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 30px;
                border-radius: 10px;
                margin-bottom: 30px;
            }
            .header h1 {
                margin: 0 0 10px 0;
                font-size: 28px;
            }
            .metadata {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 15px;
                margin-bottom: 30px;
            }
            .metadata-item {
                background: white;
                padding: 15px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .metadata-label {
                font-size: 12px;
                color: #666;
                text-transform: uppercase;
                letter-spacing: 1px;
                margin-bottom: 5px;
            }
            .metadata-value {
                font-size: 16px;
                font-weight: 600;
                color: #333;
            }
            .content {
                background: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            }
            .section {
                margin-bottom: 25px;
            }
            .section-title {
                font-size: 18px;
                font-weight: 600;
                color: #667eea;
                border-bottom: 2px solid #667eea;
                padding-bottom: 8px;
                margin-bottom: 15px;
            }
            .speaker-doctor {
                color: #2563eb;
                font-weight: 600;
                margin-top: 15px;
            }
            .speaker-patient {
                color: #059669;
                font-weight: 600;
                margin-top: 15px;
            }
            .speaker-nurse {
                color: #7c3aed;
                font-weight: 600;
                margin-top: 15px;
            }
            .pause {
                color: #9ca3af;
                font-style: italic;
                font-size: 14px;
            }
            .timestamp {
                color: #6b7280;
                font-size: 12px;
                float: right;
            }
            .transcript-line {
                margin: 10px 0;
                padding: 10px;
                background: #f9fafb;
                border-left: 3px solid transparent;
                transition: all 0.3s;
            }
            .transcript-line:hover {
                background: #f3f4f6;
                border-left-color: #667eea;
            }
            .overlap {
                background: #fef3c7;
                padding: 2px 4px;
                border-radius: 3px;
                font-style: italic;
            }
            .medical-term {
                color: #dc2626;
                font-weight: 600;
            }
            .footer {
                margin-top: 30px;
                padding: 20px;
                background: #f9fafb;
                border-radius: 10px;
                text-align: center;
                color: #6b7280;
                font-size: 14px;
            }
            @media print {
                body { background: white; }
                .header { background: #667eea; print-color-adjust: exact; }
                .no-print { display: none; }
            }
        </style>
        """
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(noteType.displayName) - \(dateFormatter.string(from: Date()))</title>
            \(css)
        </head>
        <body>
            <div class="header">
                <h1>\(noteType.displayName)</h1>
                <div style="opacity: 0.9;">Generated: \(dateFormatter.string(from: Date()))</div>
            </div>
        """
        
        // Add metadata if available
        if let metadata = metadata {
            html += """
            <div class="metadata">
                <div class="metadata-item">
                    <div class="metadata-label">Patient ID</div>
                    <div class="metadata-value">\(metadata.patientId ?? "Not specified")</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Provider</div>
                    <div class="metadata-value">\(metadata.provider ?? "Not specified")</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Encounter Type</div>
                    <div class="metadata-value">\(noteType.displayName)</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Duration</div>
                    <div class="metadata-value">\(formatDuration(metadata.duration ?? 0))</div>
                </div>
            </div>
            """
        }
        
        html += "<div class='content'>"
        
        // If we have segments, format as transcript
        if let segments = segments, !segments.isEmpty {
            html += "<div class='section'>"
            html += "<div class='section-title'>Transcription</div>"
            
            for segment in segments {
                let speakerClass = "speaker-\(segment.speaker.lowercased())"
                let timestamp = formatTimestamp(segment.startTime)
                
                html += """
                <div class='transcript-line'>
                    <span class='timestamp'>\(timestamp)</span>
                    <div class='\(speakerClass)'>\(segment.speaker):</div>
                    <div>\(escapeHTML(segment.text))</div>
                </div>
                """
            }
            
            html += "</div>"
            html += "<div class='section'>"
            html += "<div class='section-title'>Generated Note</div>"
        }
        
        // Format the note content
        let formattedNote = formatNoteContent(note, noteType: noteType)
        html += formattedNote
        
        if segments != nil {
            html += "</div>"
        }
        
        html += """
            </div>
            <div class="footer">
                <div>Generated by NotedCore with AI Enhancement</div>
                <div class="no-print" style="margin-top: 10px;">
                    <button onclick="window.print()" style="padding: 8px 16px; background: #667eea; color: white; border: none; border-radius: 5px; cursor: pointer;">
                        Print Document
                    </button>
                </div>
            </div>
        </body>
        </html>
        """
        
        return html
    }
    
    // MARK: - VTT Export (WebVTT for video/audio)
    
    static func exportToVTT(segments: [EnhancedTranscriptionSegment]) -> String {
        var vtt = "WEBVTT\n\n"
        vtt += "NOTE\nGenerated by NotedCore\n\n"
        
        for (index, segment) in segments.enumerated() {
            let startTime = formatVTTTime(segment.startTime)
            let endTime = formatVTTTime(segment.endTime)
            
            vtt += "\(index + 1)\n"
            vtt += "\(startTime) --> \(endTime)\n"
            vtt += "<v \(segment.speaker)>\(segment.text)\n\n"
        }
        
        return vtt
    }
    
    // MARK: - SRT Export (SubRip for compatibility)
    
    static func exportToSRT(segments: [EnhancedTranscriptionSegment]) -> String {
        var srt = ""
        
        for (index, segment) in segments.enumerated() {
            let startTime = formatSRTTime(segment.startTime)
            let endTime = formatSRTTime(segment.endTime)
            
            srt += "\(index + 1)\n"
            srt += "\(startTime) --> \(endTime)\n"
            srt += "\(segment.speaker): \(segment.text)\n\n"
        }
        
        return srt
    }
    
    // MARK: - JSON Export (Structured data)
    
    static func exportToJSON(
        note: String,
        noteType: NoteType,
        segments: [EnhancedTranscriptionSegment]? = nil,
        metadata: EncounterMetadata? = nil
    ) -> String {
        
        var jsonDict: [String: Any] = [
            "noteType": noteType.rawValue,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "note": note
        ]
        
        if let metadata = metadata {
            jsonDict["metadata"] = [
                "patientId": metadata.patientId ?? "",
                "provider": metadata.provider ?? "",
                "duration": metadata.duration ?? 0,
                "encounterDate": metadata.encounterDate ?? Date()
            ]
        }
        
        if let segments = segments {
            jsonDict["transcription"] = segments.map { segment in
                [
                    "speaker": segment.speaker,
                    "text": segment.text,
                    "startTime": segment.startTime,
                    "endTime": segment.endTime,
                    "confidence": segment.confidence
                ]
            }
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{}"
    }
    
    // MARK: - Markdown Export
    
    static func exportToMarkdown(
        note: String,
        noteType: NoteType,
        segments: [EnhancedTranscriptionSegment]? = nil,
        metadata: EncounterMetadata? = nil
    ) -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        
        var markdown = "# \(noteType.displayName)\n\n"
        markdown += "*Generated: \(dateFormatter.string(from: Date()))*\n\n"
        
        if let metadata = metadata {
            markdown += "## Encounter Information\n\n"
            markdown += "- **Patient ID:** \(metadata.patientId ?? "Not specified")\n"
            markdown += "- **Provider:** \(metadata.provider ?? "Not specified")\n"
            markdown += "- **Duration:** \(formatDuration(metadata.duration ?? 0))\n\n"
        }
        
        if let segments = segments, !segments.isEmpty {
            markdown += "## Transcription\n\n"
            
            var currentSpeaker = ""
            for segment in segments {
                if segment.speaker != currentSpeaker {
                    markdown += "\n**\(segment.speaker):** "
                    currentSpeaker = segment.speaker
                }
                markdown += "\(segment.text) "
            }
            markdown += "\n\n"
        }
        
        markdown += "## Clinical Note\n\n"
        markdown += note
        markdown += "\n\n---\n\n"
        markdown += "*Generated by NotedCore with AI Enhancement*\n"
        
        return markdown
    }
    
    // MARK: - Helper Functions
    
    private static func formatNoteContent(_ note: String, noteType: NoteType) -> String {
        let lines = note.components(separatedBy: .newlines)
        var formatted = ""
        
        for line in lines {
            if line.isEmpty { continue }
            
            // Check if it's a section header (all caps or ends with :)
            if line == line.uppercased() || line.hasSuffix(":") {
                formatted += "<div class='section-title'>\(escapeHTML(line))</div>"
            } else {
                // Highlight medical terms (simplified)
                var processedLine = escapeHTML(line)
                
                // Highlight common medical terms
                let medicalTerms = ["mg", "ml", "diagnosis", "treatment", "symptoms", "medication", "prescribed"]
                for term in medicalTerms {
                    processedLine = processedLine.replacingOccurrences(
                        of: "\\b\(term)\\b",
                        with: "<span class='medical-term'>\(term)</span>",
                        options: [.regularExpression, .caseInsensitive]
                    )
                }
                
                formatted += "<p>\(processedLine)</p>"
            }
        }
        
        return formatted
    }
    
    private static func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    private static func formatTimestamp(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private static func formatVTTTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, millis)
    }
    
    private static func formatSRTTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
    }
    
    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes) min \(secs) sec"
    }
}

// MARK: - Encounter Metadata
struct EncounterMetadata {
    var patientId: String?
    var provider: String?
    var duration: TimeInterval?
    var encounterDate: Date?
}