import SwiftUI

struct PacingStrategyView: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    
    private let pacingStrategies = PacingStrategy.mock
    
    var body: some View {
        VStack(spacing: HYKATheme.spacingXXL) {
            Spacer()
            
            // Main Card
            HYKACard {
                VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                    ForEach(Array(pacingStrategies.enumerated()), id: \.offset) { index, strategy in
                        VStack(alignment: .leading, spacing: HYKATheme.spacingS) {
                            HStack {
                                Text(strategy.phase)
                                    .font(HYKATheme.headline)
                                    .foregroundColor(HYKATheme.textPrimary)
                                
                                Spacer()
                                
                                Text(strategy.paceRange)
                                    .font(HYKATheme.callout)
                                    .foregroundColor(HYKATheme.accentColor)
                                    .padding(.horizontal, HYKATheme.spacingM)
                                    .padding(.vertical, HYKATheme.spacingS)
                                    .background(HYKATheme.accentColor.opacity(0.1))
                                    .cornerRadius(HYKATheme.cornerRadiusS)
                            }
                            
                            Text(strategy.description)
                                .font(HYKATheme.subheadline)
                                .foregroundColor(HYKATheme.textSecondary)
                        }
                        
                        if index < pacingStrategies.count - 1 {
                            Divider()
                                .background(HYKATheme.borderColor)
                        }
                    }
                }
            }
            .padding(.horizontal, HYKATheme.spacingL)
            
            // Bottom Text
            Text("Smart pacing strategies")
                .font(HYKATheme.subheadline)
                .foregroundColor(HYKATheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HYKATheme.spacingL)
            
            Spacer()
            
            // Buttons
            VStack(spacing: HYKATheme.spacingM) {
                HYKAButton(
                    title: "Next",
                    style: .primary,
                    action: onNext
                )
                
                HYKAButton(
                    title: "Skip",
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
    PacingStrategyView(onNext: {}, onSkip: {})
}
