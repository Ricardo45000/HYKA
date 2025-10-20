import SwiftUI

struct NutritionPlanView: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    
    private let nutritionPlan = NutritionPlan.mock
    
    var body: some View {
        VStack(spacing: HYKATheme.spacingXXL) {
            Spacer()
            
            // Main Card
            HYKACard {
                VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                    // Pre-Race Section
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        Text("Pre-Race")
                            .font(HYKATheme.headline)
                            .foregroundColor(HYKATheme.textPrimary)
                        
                        Text(nutritionPlan.preRace)
                            .font(HYKATheme.body)
                            .foregroundColor(HYKATheme.textSecondary)
                    }
                    
                    Divider()
                        .background(HYKATheme.borderColor)
                    
                    // During Race Section
                    VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                        Text("During Race")
                            .font(HYKATheme.headline)
                            .foregroundColor(HYKATheme.textPrimary)
                        
                        Text(nutritionPlan.duringRace)
                            .font(HYKATheme.body)
                            .foregroundColor(HYKATheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, HYKATheme.spacingL)
            
            // Metrics Footer
            HStack(spacing: HYKATheme.spacingXL) {
                VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                    Text("Calories/hr")
                        .font(HYKATheme.footnote)
                        .foregroundColor(HYKATheme.textSecondary)
                    
                    Text("\(nutritionPlan.caloriesPerHour)")
                        .font(HYKATheme.title3)
                        .foregroundColor(HYKATheme.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: HYKATheme.spacingXS) {
                    Text("Hydration")
                        .font(HYKATheme.footnote)
                        .foregroundColor(HYKATheme.textSecondary)
                    
                    Text("\(nutritionPlan.hydrationPerHour)ml/hr")
                        .font(HYKATheme.title3)
                        .foregroundColor(HYKATheme.textPrimary)
                }
                
                Spacer()
            }
            .padding(.horizontal, HYKATheme.spacingL)
            
            Spacer()
            
            // Buttons
            VStack(spacing: HYKATheme.spacingM) {
                HYKAButton(
                    title: "Join for free",
                    style: .primary,
                    action: onNext
                )
                
                HYKAButton(
                    title: "Log in",
                    style: .outline,
                    action: onSkip
                )
            }
            .padding(.horizontal, HYKATheme.spacingL)
            .padding(.bottom, HYKATheme.spacingXXL)
        }
    }
}

#Preview {
    NutritionPlanView(onNext: {}, onSkip: {})
}
