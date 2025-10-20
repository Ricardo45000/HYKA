import SwiftUI
import UIKit

// MARK: - Button Component
struct HYKAUIButton: View {
    enum Variant {
        case `default`
        case destructive
        case outline
        case secondary
        case ghost
        case link
    }
    
    enum Size {
        case `default`
        case sm
        case lg
        case icon
    }
    
    let title: String
    let variant: Variant
    let size: Size
    let action: () -> Void
    var isDisabled: Bool = false
    var icon: String? = nil
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: size == .icon ? 0 : 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize))
                }
                if size != .icon {
                    Text(title)
                        .font(textFont)
                }
            }
            .frame(maxWidth: size == .icon ? nil : .infinity)
            .frame(height: height)
            .padding(.horizontal, horizontalPadding)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(HYKATheme.cornerRadiusM)
            .overlay(
                RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                    .stroke(borderColor, lineWidth: variant == .outline ? 1 : 0)
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
    
    private var height: CGFloat {
        switch size {
        case .default: return 36
        case .sm: return 32
        case .lg: return 40
        case .icon: return 36
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch size {
        case .default: return icon != nil ? 12 : 16
        case .sm: return icon != nil ? 10 : 12
        case .lg: return icon != nil ? 16 : 24
        case .icon: return 0
        }
    }
    
    private var iconSize: CGFloat {
        16
    }
    
    private var textFont: Font {
        HYKATheme.button
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .default: return HYKATheme.Light.primaryForeground
        case .destructive: return .white
        case .outline: return HYKATheme.Light.foreground
        case .secondary: return HYKATheme.Light.secondaryForeground
        case .ghost: return HYKATheme.Light.foreground
        case .link: return HYKATheme.hykaPurple
        }
    }
    
    private var backgroundColor: Color {
        switch variant {
        case .default: return HYKATheme.hykaPurple
        case .destructive: return HYKATheme.Light.destructive
        case .outline: return HYKATheme.Light.background
        case .secondary: return HYKATheme.Light.secondary
        case .ghost: return .clear
        case .link: return .clear
        }
    }
    
    private var borderColor: Color {
        variant == .outline ? HYKATheme.Light.border : .clear
    }
}

// MARK: - Input Component
struct HYKAUIInput: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    
    var body: some View {
        HStack(spacing: HYKATheme.spacingM) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(HYKATheme.Light.mutedForeground)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(HYKATheme.input)
                    .textContentType(textContentType)
            } else {
                TextField(placeholder, text: $text)
                    .font(HYKATheme.input)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
            }
        }
        .padding(.horizontal, HYKATheme.spacingM)
        .frame(height: 48)
        .background(HYKATheme.Light.inputBackground)
        .cornerRadius(HYKATheme.cornerRadiusM)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .stroke(HYKATheme.Light.border, lineWidth: 1)
        )
    }
}

// MARK: - Card Component
struct HYKAUICard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 24
    
    init(padding: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(padding)
        .background(HYKATheme.Light.card)
        .cornerRadius(HYKATheme.cornerRadiusXL)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusXL)
                .stroke(HYKATheme.Light.border, lineWidth: 1)
        )
    }
}

// MARK: - Badge Component
struct HYKAUIBadge: View {
    enum Variant {
        case `default`
        case secondary
        case destructive
        case outline
    }
    
    let title: String
    let variant: Variant
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
            }
            Text(title)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .foregroundColor(foregroundColor)
        .background(backgroundColor)
        .cornerRadius(HYKATheme.cornerRadiusM)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusM)
                .stroke(borderColor, lineWidth: variant == .outline ? 1 : 0)
        )
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .default: return HYKATheme.Light.primaryForeground
        case .secondary: return HYKATheme.Light.secondaryForeground
        case .destructive: return .white
        case .outline: return HYKATheme.Light.foreground
        }
    }
    
    private var backgroundColor: Color {
        switch variant {
        case .default: return HYKATheme.hykaPurple
        case .secondary: return HYKATheme.Light.secondary
        case .destructive: return HYKATheme.Light.destructive
        case .outline: return .clear
        }
    }
    
    private var borderColor: Color {
        variant == .outline ? HYKATheme.Light.border : .clear
    }
}

// MARK: - Checkbox Component
struct HYKAUICheckbox: View {
    @Binding var isChecked: Bool
    let label: String?
    
    init(isChecked: Binding<Bool>, label: String? = nil) {
        self._isChecked = isChecked
        self.label = label
    }
    
    var body: some View {
        Button(action: { isChecked.toggle() }) {
            HStack(spacing: HYKATheme.spacingM) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isChecked ? HYKATheme.hykaPurple : HYKATheme.Light.inputBackground)
                        .frame(width: 16, height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isChecked ? HYKATheme.hykaPurple : HYKATheme.Light.border, lineWidth: 1)
                        .frame(width: 16, height: 16)
                    
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                if let label = label {
                    Text(label)
                        .font(HYKATheme.label)
                        .foregroundColor(HYKATheme.Light.foreground)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Radio Group Component
struct HYKAUIRadioButton: View {
    let isSelected: Bool
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: HYKATheme.spacingM) {
                ZStack {
                    Circle()
                        .fill(HYKATheme.Light.inputBackground)
                        .frame(width: 16, height: 16)
                    
                    Circle()
                        .stroke(HYKATheme.Light.border, lineWidth: 1)
                        .frame(width: 16, height: 16)
                    
                    if isSelected {
                        Circle()
                            .fill(HYKATheme.hykaPurple)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(label)
                    .font(HYKATheme.label)
                    .foregroundColor(HYKATheme.Light.foreground)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Switch Component
struct HYKAUISwitch: View {
    @Binding var isOn: Bool
    let label: String?
    
    init(isOn: Binding<Bool>, label: String? = nil) {
        self._isOn = isOn
        self.label = label
    }
    
    var body: some View {
        HStack {
            if let label = label {
                Text(label)
                    .font(HYKATheme.label)
                    .foregroundColor(HYKATheme.Light.foreground)
                Spacer()
            }
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: HYKATheme.hykaPurple))
        }
    }
}

// MARK: - Progress Component
struct HYKAUIProgress: View {
    let value: Double // 0.0 to 1.0
    var height: CGFloat = 8
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(HYKATheme.Light.muted)
                    .frame(height: height)
                
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(HYKATheme.hykaPurple)
                    .frame(width: geometry.size.width * value, height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Separator Component
struct HYKAUISeparator: View {
    var body: some View {
        Rectangle()
            .fill(HYKATheme.Light.border)
            .frame(height: 1)
    }
}

// MARK: - Alert Component
struct HYKAUIAlert: View {
    enum Variant {
        case `default`
        case destructive
    }
    
    let title: String
    let description: String?
    let variant: Variant
    var icon: String? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: HYKATheme.spacingM) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(textColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
                
                if let description = description {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(textColor.opacity(0.9))
                }
            }
            
            Spacer()
        }
        .padding(HYKATheme.spacingM)
        .background(HYKATheme.Light.card)
        .cornerRadius(HYKATheme.cornerRadiusL)
        .overlay(
            RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusL)
                .stroke(HYKATheme.Light.border, lineWidth: 1)
        )
    }
    
    private var textColor: Color {
        variant == .destructive ? HYKATheme.Light.destructive : HYKATheme.Light.foreground
    }
}

// MARK: - Skeleton Component
struct HYKAUISkeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8
    
    @State private var isAnimating = false
    
    var body: some View {
        Rectangle()
            .fill(HYKATheme.Light.muted)
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .opacity(isAnimating ? 0.5 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Tabs Component
struct HYKAUITabs<Content: View>: View {
    let tabs: [String]
    @Binding var selectedTab: Int
    let content: Content
    
    init(tabs: [String], selectedTab: Binding<Int>, @ViewBuilder content: () -> Content) {
        self.tabs = tabs
        self._selectedTab = selectedTab
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: HYKATheme.spacingL) {
            HStack(spacing: 3) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    tabButton(for: tab, at: index)
                }
            }
            .padding(3)
            .background(HYKATheme.Light.muted)
            .cornerRadius(HYKATheme.cornerRadiusXL)
            
            content
        }
    }
    
    private func tabButton(for tab: String, at index: Int) -> some View {
        let isSelected = selectedTab == index
        
        return Button(action: { selectedTab = index }) {
            Text(tab)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? HYKATheme.Light.foreground : HYKATheme.Light.mutedForeground)
                .padding(.horizontal, HYKATheme.spacingM)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(isSelected ? HYKATheme.Light.card : Color.clear)
                .cornerRadius(HYKATheme.cornerRadiusXL)
                .overlay(
                    RoundedRectangle(cornerRadius: HYKATheme.cornerRadiusXL)
                        .stroke(isSelected ? HYKATheme.Light.border : Color.clear, lineWidth: 1)
                )
        }
    }
}

// MARK: - Label Component
struct HYKAUILabel: View {
    let text: String
    var isRequired: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(HYKATheme.label)
                .foregroundColor(HYKATheme.Light.foreground)
            
            if isRequired {
                Text("*")
                    .font(HYKATheme.label)
                    .foregroundColor(HYKATheme.Light.destructive)
            }
        }
    }
}

// MARK: - Keyboard Dismissal Modifier
struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        self.modifier(DismissKeyboardOnTap())
    }
}

struct WrapLayout<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        FlowLayout(spacing: spacing, lineSpacing: lineSpacing, content: content)
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            content()
                .alignmentGuide(.leading) { view in
                    if abs(width - view.width) > geometry.size.width {
                        width = 0
                        height -= view.height + lineSpacing
                    }
                    let result = width
                    if view == view {
                        width -= (view.width + spacing)
                    }
                    return result
                }
                .alignmentGuide(.top) { view in
                    let result = height
                    if view == view {
                        height -= (view.height + lineSpacing)
                    }
                    return result
                }
        }
    }
}

