import SwiftUI

struct TargetRaceCard: View {
    let target: Target
    let onEditTap: () -> Void  // Add a callback function
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 16) {
                // Title and edit button
                HStack {
                    SectionHeader(title: NSLocalizedString("target_race_card.title", comment: "Target Race"), systemImage: "flag.filled.and.flag.crossed")
                    
                    Spacer()
                    
                    Button(action: {
                        onEditTap()
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                }
                
                // Race basic information
                VStack(alignment: .leading, spacing: 10) {
                    // Name
                    HStack(alignment: .center, spacing: 12) {
                        Text(target.name)
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Calculate days remaining until race date using target's timezone
                        let daysRemaining = TrainingDateUtils.calculateDaysRemaining(raceDate: target.raceDate, timezone: target.timezone)
                        Text("\(daysRemaining) \(NSLocalizedString("target_race_card.days_unit", comment: "Days Unit"))")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.15))
                            )
                    }
                    
                    // Date, distance and countdown days in same row
                    HStack(alignment: .center, spacing: 12) {
                        // Date
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            
                            Text(formatDate(target.raceDate))
                                .font(.subheadline)
                        }
                        
                        Spacer()

                        // Distance
                        Text("\(target.distanceKm) \(NSLocalizedString("target_race_card.distance_unit", comment: "Distance Unit"))")
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.15))
                            )
                        
                    }
                    
                    // Target finish time and pace
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("target_race_card.target_finish_time", comment: "Target Finish Time"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatTime(target.targetTime))
                                .font(.headline)
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("target_race_card.target_pace", comment: "Target Pace"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(target.targetPace) \(NSLocalizedString("target_race_card.per_kilometer", comment: "Per Kilometer"))")
                                .font(.headline)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6).opacity(0.5))
                    )
                }
            }
        }
    }

    // Format date with timezone
    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale.current

        // 使用目標的時區
        if let timeZone = TimeZone(identifier: target.timezone) {
            formatter.timeZone = timeZone
        }

        return formatter.string(from: date)
    }
    
    // Format time
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
    

}
