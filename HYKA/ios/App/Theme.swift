import SwiftUI

struct HYKATheme {
    // MARK: - Colors (mapped from CSS variables)
    
    // Primary brand color (preserved from existing)
    static let hykaPurple = Color(red: 0.63, green: 0.0, blue: 1.0) // #A020F0
    static let accentColor = hykaPurple
    
    // Light mode colors (from :root)
    struct Light {
        static let background = Color.white
        static let foreground = Color(white: 0.145) // oklch(0.145 0 0)
        static let card = Color.white
        static let cardForeground = Color(white: 0.145)
        static let popover = Color.white
        static let popoverForeground = Color(white: 0.145)
        static let primary = Color(red: 0.012, green: 0.008, blue: 0.075) // #030213
        static let primaryForeground = Color.white
        static let secondary = Color(white: 0.95) // oklch(0.95 0.0058 264.53)
        static let secondaryForeground = Color(red: 0.012, green: 0.008, blue: 0.075)
        static let muted = Color(red: 0.925, green: 0.925, blue: 0.941) // #ececf0
        static let mutedForeground = Color(red: 0.443, green: 0.443, blue: 0.510) // #717182
        static let accent = Color(red: 0.914, green: 0.922, blue: 0.937) // #e9ebef
        static let accentForeground = Color(red: 0.012, green: 0.008, blue: 0.075)
        static let destructive = Color(red: 0.831, green: 0.094, blue: 0.239) // #d4183d
        static let destructiveForeground = Color.white
        static let border = Color.black.opacity(0.1)
        static let input = Color.clear
        static let inputBackground = Color(red: 0.953, green: 0.953, blue: 0.961) // #f3f3f5
        static let switchBackground = Color(red: 0.796, green: 0.808, blue: 0.831) // #cbced4
        static let ring = Color(white: 0.708) // oklch(0.708 0 0)
    }
    
    // Dark mode colors (from .dark)
    struct Dark {
        static let background = Color(white: 0.145)
        static let foreground = Color(white: 0.985)
        static let card = Color(white: 0.145)
        static let cardForeground = Color(white: 0.985)
        static let popover = Color(white: 0.145)
        static let popoverForeground = Color(white: 0.985)
        static let primary = Color(white: 0.985)
        static let primaryForeground = Color(white: 0.205)
        static let secondary = Color(white: 0.269)
        static let secondaryForeground = Color(white: 0.985)
        static let muted = Color(white: 0.269)
        static let mutedForeground = Color(white: 0.708)
        static let accent = Color(white: 0.269)
        static let accentForeground = Color(white: 0.985)
        static let destructive = Color(white: 0.396) // oklch(0.396 0.141 25.723)
        static let destructiveForeground = Color(white: 0.637) // oklch(0.637 0.237 25.331)
        static let border = Color(white: 0.269)
        static let input = Color(white: 0.269)
        static let inputBackground = Color(white: 0.269)
        static let switchBackground = Color(white: 0.269)
        static let ring = Color(white: 0.439)
    }
    
    // Convenience aliases (light mode defaults)
    static let backgroundColor = Light.background
    static let cardBackground = Light.card
    static let textPrimary = Light.foreground
    static let textSecondary = Light.mutedForeground
    static let textOnAccent = Light.primaryForeground
    static let borderColor = Light.border
    static let selectedBorderColor = accentColor
    static let progressTrackColor = Light.muted
    static let shadowColor = Light.border
    
    // MARK: - Typography (matching hyka.app website fonts)
    // Fonts: Plus Jakarta Sans (headings) and Inter (body text)
    // Base font size: 14px (reduced by 15% for iPhone 16 Pro)
    
    // Custom font names (PostScript names)
    // Variable fonts use base name, static fonts use name-weight pattern
    private static let plusJakartaSansVariable = "PlusJakartaSans"
    private static let interVariable = "Inter"
    
    // Helper function to create custom font with system fallback
    private static func customFont(name: String, size: CGFloat, weight: Font.Weight, useVariable: Bool = true) -> Font {
        // Map Font.Weight to weight names for static fonts
        let weightName: String
        switch weight {
        case .ultraLight, .thin:
            weightName = "Thin"
        case .light:
            weightName = "Light"
        case .regular:
            weightName = "Regular"
        case .medium:
            weightName = "Medium"
        case .semibold:
            weightName = "SemiBold"
        case .bold:
            weightName = "Bold"
        case .heavy:
            weightName = "ExtraBold"
        case .black:
            weightName = "Black"
        @unknown default:
            weightName = "Regular"
        }
        
        // Try variable font first (iOS 13+), then static fonts
        var fontNames: [String] = []
        
        if useVariable {
            // Variable fonts - use base name, iOS handles weight internally
            fontNames.append(name)
        }
        
        // Static font patterns (for Plus Jakarta Sans)
        if name == plusJakartaSansVariable {
            fontNames.append(contentsOf: [
                "\(name)-\(weightName)",
                "\(name)\(weightName)"
            ])
        }
        
        // Static font patterns (for Inter - note: Inter static fonts use "Inter_18pt-Weight" format)
        if name == interVariable {
            fontNames.append(contentsOf: [
                "Inter_18pt-\(weightName)",
                "Inter-\(weightName)",
                "\(name)-\(weightName)"
            ])
        }
        
        // Try each pattern until one works
        for fontName in fontNames {
            if UIFont(name: fontName, size: size) != nil {
                return Font.custom(fontName, size: size)
            }
        }
        
        // Fallback to system font
        return Font.system(size: size, weight: weight, design: .default)
    }
    
    // Helper function for Plus Jakarta Sans (headings)
    private static func plusJakartaSansFont(size: CGFloat, weight: Font.Weight) -> Font {
        return customFont(name: plusJakartaSansVariable, size: size, weight: weight, useVariable: true)
    }
    
    // Helper function for Inter (body text)
    private static func interFont(size: CGFloat, weight: Font.Weight) -> Font {
        return customFont(name: interVariable, size: size, weight: weight, useVariable: true)
    }
    
    // CSS typography sizes (reduced by 15%)
    static let textBase: CGFloat = 14 // 1rem (--text-base) reduced from 16
    static let textLG: CGFloat = 15 // 1.125rem (--text-lg) reduced from 18
    static let textXL: CGFloat = 17 // 1.25rem (--text-xl) reduced from 20
    static let text2XL: CGFloat = 20 // 1.5rem (--text-2xl) reduced from 24
    
    // Font weights
    static let fontWeightNormal: Font.Weight = .regular // 400
    static let fontWeightMedium: Font.Weight = .medium // 500
    
    // Typography styles (matching CSS h1-h4, p, label, button, input)
    // Headings use Plus Jakarta Sans, body uses Inter
    static let h1 = plusJakartaSansFont(size: text2XL, weight: .semibold) // 20px, semibold (600)
    static let h2 = plusJakartaSansFont(size: textXL, weight: .semibold) // 17px, semibold (600)
    static let h3 = plusJakartaSansFont(size: textLG, weight: .semibold) // 15px, semibold (600)
    static let h4 = plusJakartaSansFont(size: textBase, weight: .semibold) // 14px, semibold (600)
    static let body = interFont(size: textBase, weight: fontWeightNormal) // 14px, regular (400) - Inter
    static let label = interFont(size: textBase, weight: fontWeightMedium) // 14px, medium (500) - Inter
    static let button = plusJakartaSansFont(size: textBase, weight: fontWeightMedium) // 14px, medium (500) - Plus Jakarta Sans
    static let input = interFont(size: textBase, weight: fontWeightNormal) // 14px, regular (400) - Inter
    
    // Legacy aliases for backward compatibility (reduced by 15%)
    static let largeTitle = plusJakartaSansFont(size: 29, weight: .bold) // Plus Jakarta Sans
    static let title1 = plusJakartaSansFont(size: 24, weight: .bold) // Plus Jakarta Sans
    static let title2 = h2
    static let title3 = plusJakartaSansFont(size: 17, weight: .semibold) // Plus Jakarta Sans
    static let headline = plusJakartaSansFont(size: 14, weight: .semibold) // Plus Jakarta Sans
    static let callout = body // Inter
    static let subheadline = interFont(size: 13, weight: .regular) // Inter
    static let footnote = interFont(size: 11, weight: .regular) // Inter
    static let caption = interFont(size: 10, weight: .regular) // Inter
    
    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 24
    static let spacingXXXL: CGFloat = 32
    
    // MARK: - Corner Radius (mapped from CSS variables)
    // Base radius: 0.625rem (10px) --radius
    static let radius: CGFloat = 10 // 0.625rem (--radius)
    static let radiusSM: CGFloat = 6 // calc(var(--radius) - 4px) = 6px
    static let radiusMD: CGFloat = 8 // calc(var(--radius) - 2px) = 8px
    static let radiusLG: CGFloat = 10 // var(--radius) = 10px
    static let radiusXL: CGFloat = 14 // calc(var(--radius) + 4px) = 14px
    
    // Legacy aliases for backward compatibility
    static let cornerRadiusS: CGFloat = radiusSM
    static let cornerRadiusM: CGFloat = radiusMD
    static let cornerRadiusL: CGFloat = radiusLG
    static let cornerRadiusXL: CGFloat = radiusXL
    
    // MARK: - Shadow
    static let cardShadow = Shadow(
        color: shadowColor,
        radius: 8,
        x: 0,
        y: 2
    )
    
    static let buttonShadow = Shadow(
        color: shadowColor,
        radius: 4,
        x: 0,
        y: 1
    )
}

// MARK: - Reusable Components

struct HYKACard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: HYKATheme.spacingM) {
            content
        }
        .padding(HYKATheme.spacingL)
        .background(HYKATheme.cardBackground)
        .cornerRadius(HYKATheme.cornerRadiusL)
        .shadow(
            color: HYKATheme.cardShadow.color,
            radius: HYKATheme.cardShadow.radius,
            x: HYKATheme.cardShadow.x,
            y: HYKATheme.cardShadow.y
        )
    }
}

struct HYKAOutlinedCard<Content: View>: View {
    let borderColor: Color
    let content: Content
    
    init(borderColor: Color, @ViewBuilder content: () -> Content) {
        self.borderColor = borderColor
        self.content = content()
    }
    
    var body: some View {
        HYKACard {
            content
        }
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                .stroke(borderColor, lineWidth: 2)
        )
    }
}

struct HYKAButton: View {
    let title: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
        case outline
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HYKATheme.headline)
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .cornerRadius(HYKATheme.cornerRadiusM)
        }
        .shadow(
            color: HYKATheme.buttonShadow.color,
            radius: HYKATheme.buttonShadow.radius,
            x: HYKATheme.buttonShadow.x,
            y: HYKATheme.buttonShadow.y
        )
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return HYKATheme.accentColor
        case .secondary:
            return HYKATheme.backgroundColor
        case .outline:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return HYKATheme.textOnAccent
        case .secondary, .outline:
            return HYKATheme.textPrimary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .secondary:
            return Color.clear
        case .outline:
            return HYKATheme.borderColor
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .primary, .secondary:
            return 0
        case .outline:
            return 1
        }
    }
}

struct HYKAProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    private var progress: Double {
        Double(currentStep) / Double(totalSteps)
    }
    
    var body: some View {
        VStack(spacing: HYKATheme.spacingS) {
            HStack {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(HYKATheme.footnote)
                    .foregroundColor(HYKATheme.textSecondary)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(HYKATheme.footnote)
                    .foregroundColor(HYKATheme.textSecondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(HYKATheme.progressTrackColor)
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(HYKATheme.accentColor)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
    }
}

struct HYKAChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HYKATheme.callout)
                .foregroundColor(isSelected ? HYKATheme.textOnAccent : HYKATheme.textPrimary)
                .padding(.horizontal, HYKATheme.spacingM)
                .padding(.vertical, HYKATheme.spacingS)
                .background(isSelected ? HYKATheme.accentColor : HYKATheme.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusS)
                        .stroke(isSelected ? HYKATheme.accentColor : HYKATheme.borderColor, lineWidth: 1)
                )
                .cornerRadius(HYKATheme.cornerRadiusS)
        }
    }
}

struct HYKAHeader: View {
    let title: String
    var subtitle: String? = nil
    let showProgress: Bool
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(HYKATheme.title2)
                        .foregroundColor(HYKATheme.textOnAccent)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(HYKATheme.subheadline)
                            .foregroundColor(Color.white.opacity(0.8))
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, HYKATheme.spacingL)
            .padding(.top, HYKATheme.spacingL)
            .padding(.bottom, HYKATheme.spacingM)
            
            if showProgress {
                HYKAProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.horizontal, HYKATheme.spacingL)
                    .padding(.bottom, HYKATheme.spacingL)
            }
        }
        .background(HYKATheme.accentColor)
    }
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Color Extension
extension Color {
    /// HYKA brand purple color (#A020F0)
    static let hykaPurple = HYKATheme.hykaPurple
}

// MARK: - Forward Slant Modifier (for italic effect)
/// This modifier applies a shear transform so heavy system text looks "italic"
struct ForwardSlant: ViewModifier {
    let degrees: Double   // e.g. 10-12 looks sporty

    func body(content: Content) -> some View {
        content
            .transformEffect(
                CGAffineTransform(a: 1,
                                  b: 0,
                                  c: CGFloat(-tan(degrees * .pi / 180)),
                                  d: 1,
                                  tx: 0,
                                  ty: 0)
            )
    }
}
