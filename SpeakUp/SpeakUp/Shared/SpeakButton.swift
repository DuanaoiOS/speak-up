import SwiftUI
import SwiftData

struct SpeakButton: View {
    let text: String

    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var settings: [SettingsModel]

    @State private var ttsService = TTSService()

    private var rate: Float { Float(settings.first?.ttsRate ?? 0.35) }

    var body: some View {
        Button {
            ttsService.speak(text, rate: rate)
        } label: {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDisappear {
            ttsService.stop()
        }
    }
}
