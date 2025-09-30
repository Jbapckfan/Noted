import SwiftUI

struct SpeakerLanesView: View {
    @ObservedObject var voiceEngine = VoiceIdentificationEngine.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Speaker Lanes", systemImage: "person.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 20)
            
            ForEach(VoiceIdentificationEngine.Speaker.allCases, id: \.self) { speaker in
                if speaker != .unknown {
                    lane(for: speaker)
                }
            }
        }
    }
    
    private func lane(for speaker: VoiceIdentificationEngine.Speaker) -> some View {
        let color = Color(hex: speaker.color)
        let recent = voiceEngine.speakerSegments.filter { $0.speaker == speaker }.suffix(2)
        return HStack(alignment: .top, spacing: 8) {
            Text(speaker.icon)
                .font(.system(size: 16))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(speaker.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color)
                    if let conf = recent.last?.confidence {
                        Text("\(Int(conf * 100))%")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                ForEach(Array(recent.enumerated()), id: \.offset) { _, seg in
                    Text(seg.text)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
