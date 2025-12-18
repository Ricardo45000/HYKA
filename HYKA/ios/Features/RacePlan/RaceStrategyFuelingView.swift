import SwiftUI

struct RaceStrategyFuelingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HYKATheme.spacingXL) {
                // Top summary row
                HYKACard {
                    HStack(spacing: HYKATheme.spacingXL) {
                        VStack(alignment: .leading) {
                            Text("Carbs")
                                .font(HYKATheme.footnote)
                                .foregroundColor(HYKATheme.textSecondary)
                            Text("292 g")
                                .font(HYKATheme.title3)
                        }
                        VStack(alignment: .leading) {
                            Text("Sodium")
                                .font(HYKATheme.footnote)
                                .foregroundColor(HYKATheme.textSecondary)
                            Text("881 mg")
                                .font(HYKATheme.title3)
                        }
                        VStack(alignment: .leading) {
                            Text("Water")
                                .font(HYKATheme.footnote)
                                .foregroundColor(HYKATheme.textSecondary)
                            Text("2083 ml")
                                .font(HYKATheme.title3)
                        }
                    }
                }
                
                // Recommended Fueling
                VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                    Text("Recommended Fueling")
                        .font(HYKATheme.title3)
                    HYKACard {
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            Text("4 Tailwind Endurance • 200 g carbs • 800 mg Na")
                            Text("2 Gels • 92 g carbs • 81 mg Na")
                        }
                        .font(HYKATheme.subheadline)
                        .foregroundColor(HYKATheme.textPrimary)
                    }
                }
                
                // Hydration Plan
                VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                    Text("Hydration Plan")
                        .font(HYKATheme.title3)
                    HYKACard {
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            Text("Carry 5 soft flasks • 2083 ml")
                            Text("Refill available at Station 1")
                        }
                        .font(HYKATheme.subheadline)
                        .foregroundColor(HYKATheme.textPrimary)
                    }
                }
                
                // Footer chips
                HStack(spacing: HYKATheme.spacingM) {
                    HYKAChip(title: "Hydration", isSelected: true, action: {})
                    HYKAChip(title: "Gels", isSelected: true, action: {})
                    HYKAChip(title: "Food", isSelected: false, action: {})
                }
            }
            .padding(HYKATheme.spacingL)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(HYKATheme.backgroundColor)
    }
}

#Preview {
    RaceStrategyFuelingView()
}


