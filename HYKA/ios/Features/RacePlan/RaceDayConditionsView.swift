import SwiftUI

struct RaceDayConditionsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HYKATheme.spacingXL) {
                Text("Race Day Conditions")
                    .font(HYKATheme.title2)
                    .foregroundColor(HYKATheme.textPrimary)
                
                HYKACard {
                    VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                        HStack {
                            Text("Weather Forecast")
                                .font(HYKATheme.title3)
                            Spacer()
                            Text("Chamonix, France")
                                .font(HYKATheme.subheadline)
                                .foregroundColor(HYKATheme.textSecondary)
                        }
                        Divider().background(HYKATheme.borderColor)
                        HStack {
                            Text("Temp 12–18 °C")
                            Spacer()
                            Text("Partly Cloudy")
                            Spacer()
                            Text("Wind 10–15 km/h")
                            Spacer()
                            Text("Humidity variable")
                        }
                        .font(HYKATheme.subheadline)
                        .foregroundColor(HYKATheme.textPrimary)
                    }
                }
                
                HStack(spacing: HYKATheme.spacingM) {
                    HYKAButton(title: "Download", style: .primary, action: {})
                    HYKAButton(title: "Sync with Garmin", style: .outline, action: {})
                }
            }
            .padding(HYKATheme.spacingL)
        }
        .background(HYKATheme.backgroundColor)
    }
}

#Preview {
    RaceDayConditionsView()
}


