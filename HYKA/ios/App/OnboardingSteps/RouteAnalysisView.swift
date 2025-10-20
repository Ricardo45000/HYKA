import SwiftUI

struct RouteAnalysisView: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: HYKATheme.spacingXXL) {
            Spacer()
            
            // Main Card
            HYKACard {
                VStack(alignment: .leading, spacing: HYKATheme.spacingL) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        Text("GPX File Ready")
                            .font(HYKATheme.title3)
                            .foregroundColor(HYKATheme.textPrimary)
                        
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(HYKATheme.accentColor)
                                .frame(width: 20)
                            
                            Text("Distance: 50K")
                                .font(HYKATheme.body)
                                .foregroundColor(HYKATheme.textPrimary)
                        }
                        
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(HYKATheme.accentColor)
                                .frame(width: 20)
                            
                            Text("Elevation: 2,400m")
                                .font(HYKATheme.body)
                                .foregroundColor(HYKATheme.textPrimary)
                        }
                        
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            
                            Text("Difficulty: Hard")
                                .font(HYKATheme.body)
                                .foregroundColor(HYKATheme.textPrimary)
                        }
                    }
                }
            }
            .padding(.horizontal, HYKATheme.spacingL)
            
            // Bottom Text
            Text("Upload your race route")
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
    RouteAnalysisView(onNext: {}, onSkip: {})
}
