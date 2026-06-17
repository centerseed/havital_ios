import SwiftUI

struct TrainingProgressNudge: View {
    let content: NoPlanConversionContent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundColor(.accentColor)
            Text(progressText)
                .font(AppFont.bodySmall())
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var progressText: String {
        if content.showsRaceCountdown, let race = content.raceName, let days = content.daysToRace {
            return String(format: NSLocalizedString("paywall.conversion.progress_race", comment: ""),
                          content.completedWeeks, content.totalWeeks, race, days)
        }
        return String(format: NSLocalizedString("paywall.conversion.progress", comment: ""),
                      content.completedWeeks, content.totalWeeks)
    }
}
