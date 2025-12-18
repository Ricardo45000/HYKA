import SwiftUI

struct RaceStrategyCalendarView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HYKATheme.spacingXL) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Race Calendar")
                        .font(HYKATheme.title2)
                        .foregroundColor(HYKATheme.textPrimary)
                    Text("Comprehensive pacing and nutrition strategy for each section")
                        .font(HYKATheme.subheadline)
                        .foregroundColor(HYKATheme.textSecondary)
                }
                
                // Section 1: Start → Station 1
                VStack(spacing: HYKATheme.spacingL) {
                    // Pacing card
                    HYKAOutlinedCard(borderColor: Color.green.opacity(0.6)) {
                        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                            HStack {
                                Text("Pacing: Start → Station 1")
                                    .font(HYKATheme.headline)
                                Spacer()
                                Text("Easy")
                                    .font(HYKATheme.footnote)
                                    .foregroundColor(.green)
                            }
                            HStack {
                                Label("0K – 25K (25.0K)", systemImage: "ruler")
                                Spacer()
                                Label("4h 7m", systemImage: "clock")
                                Spacer()
                                Label("120-130 bpm", systemImage: "heart.fill")
                            }
                            .font(HYKATheme.footnote)
                            .foregroundColor(HYKATheme.textSecondary)
                            
                            HStack {
                                Text("Est. Pace 9:53 /km")
                                Spacer()
                                Text("Gain +477 m")
                                Spacer()
                                Text("Loss -185 m")
                            }
                            .font(HYKATheme.footnote)
                            .foregroundColor(HYKATheme.textSecondary)
                        }
                    }
                    
                    // Fueling card
                    HYKAOutlinedCard(borderColor: HYKATheme.accentColor.opacity(0.6)) {
                        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                            Text("Fueling: Station 1")
                                .font(HYKATheme.headline)
                            HStack {
                                Text("Carbs 60 g")
                                Spacer()
                                Text("Sodium 400 mg")
                                Spacer()
                                Text("Water 500 ml")
                            }
                            .font(HYKATheme.footnote)
                            .foregroundColor(HYKATheme.textSecondary)
                            
                            VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                                Text("Items: 1 gel, 250 ml water")
                                Text("Hydration: Refill available")
                            }
                            .font(HYKATheme.footnote)
                            .foregroundColor(HYKATheme.textSecondary)
                        }
                    }
                }
                
                // Repeat for next sections (Station 1 → 2)
                VStack(spacing: HYKATheme.spacingL) {
                    HYKAOutlinedCard(borderColor: Color.blue.opacity(0.6)) {
                        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                            HStack {
                                Text("Pacing: Station 1 → Station 2")
                                    .font(HYKATheme.headline)
                                Spacer()
                                Text("Moderate")
                                    .font(HYKATheme.footnote)
                                    .foregroundColor(.green)
                            }
                            HStack {
                                Label("15 km", systemImage: "ruler")
                                Spacer()
                                Label("2h 05m", systemImage: "clock")
                                Spacer()
                                Label("130-150 bpm", systemImage: "heart.fill")
                            }
                            .font(HYKATheme.footnote)
                            .foregroundColor(HYKATheme.textSecondary)
                            HStack {
                                Text("Pace 8:20/km")
                                Spacer()
                                Text("Gain 800 m")
                                Spacer()
                                Text("Loss 200 m")
                            }
                            .font(HYKATheme.footnote)
                            .foregroundColor(HYKATheme.textSecondary)
                        }
                    }
                    
                    HYKAOutlinedCard(borderColor: HYKATheme.accentColor.opacity(0.6)) {
                        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                            Text("Fueling: Station 2")
                                .font(HYKATheme.headline)
                            HStack {
                                Text("Carbs 90 g")
                                Spacer()
                                Text("Sodium 600 mg")
                                Spacer()
                                Text("Water 750 ml")
                            }
                            .font(HYKATheme.footnote)
                            .foregroundColor(HYKATheme.textSecondary)
                            VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                                Text("Items: 1 bar, 1 gel, 500 ml water")
                                Text("Hydration: Carry extra, refill at next station")
                            }
                            .font(HYKATheme.footnote)
                            .foregroundColor(HYKATheme.textSecondary)
                        }
                    }
                }
                
                HStack(spacing: HYKATheme.spacingM) {
                    HYKAButton(title: "Download", style: .primary, action: {})
                    HYKAButton(title: "Sync with Garmin", style: .outline, action: {})
                }
            }
            .padding(HYKATheme.spacingL)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(HYKATheme.backgroundColor)
    }
}

#Preview {
    RaceStrategyCalendarView()
}


