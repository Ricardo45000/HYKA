import SwiftUI

struct RaceStrategySummaryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HYKATheme.spacingXL) {
                HYKAHeader(title: "Your Race Strategy", subtitle: "Personalized plan for UTMB", showProgress: false, currentStep: 1, totalSteps: 1)
                
                HYKACard {
                    VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                        HStack {
                            Text("Race Date")
                                .foregroundColor(HYKATheme.textSecondary)
                                .font(HYKATheme.footnote)
                            Spacer()
                            Text("Aug 21, 2026")
                                .font(HYKATheme.body)
                        }
                        Divider().background(HYKATheme.borderColor)
                        HStack {
                            Text("Distance")
                                .foregroundColor(HYKATheme.textSecondary)
                                .font(HYKATheme.footnote)
                            Spacer()
                            Text("50K")
                                .font(HYKATheme.body)
                        }
                        Divider().background(HYKATheme.borderColor)
                        HStack {
                            Text("Elevation")
                                .foregroundColor(HYKATheme.textSecondary)
                                .font(HYKATheme.footnote)
                            Spacer()
                            Text("2400 m")
                                .font(HYKATheme.body)
                        }
                        Divider().background(HYKATheme.borderColor)
                        HStack {
                            Text("Est. Time")
                                .foregroundColor(HYKATheme.textSecondary)
                                .font(HYKATheme.footnote)
                            Spacer()
                            Text("7h 45m")
                                .font(HYKATheme.body)
                        }
                        
                        HYKAButton(title: "Share with Crew", style: .outline, action: {})
                    }
                }
                
                Text("Download your strategy or connect to Garmin for real-time guidance")
                    .font(HYKATheme.footnote)
                    .foregroundColor(HYKATheme.textSecondary)
                
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
    RaceStrategySummaryView()
}


