import SwiftUI

// MARK: - Professional Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        // Primary brand colors
        static let primary = Color(hex: "007AFF")
        static let primaryDark = Color(hex: "0051D5")
        static let accent = Color(hex: "5856D6")
        
        // Semantic colors
        static let success = Color(hex: "34C759")
        static let warning = Color(hex: "FF9500")
        static let danger = Color(hex: "FF3B30")
        static let info = Color(hex: "5AC8FA")
        
        // Background colors
        static let background = Color(hex: "F2F2F7")
        static let secondaryBackground = Color.white
        static let tertiaryBackground = Color(hex: "EFEFF4")
        static let groupedBackground = Color(hex: "F2F2F7")
        
        // Dark mode backgrounds
        static let darkBackground = Color(hex: "000000")
        static let darkSecondaryBackground = Color(hex: "1C1C1E")
        static let darkTertiaryBackground = Color(hex: "2C2C2E")
        
        // Text colors
        static let primaryText = Color(hex: "000000").opacity(0.9)
        static let secondaryText = Color(hex: "3C3C43").opacity(0.6)
        static let tertiaryText = Color(hex: "3C3C43").opacity(0.3)
        static let placeholderText = Color(hex: "3C3C43").opacity(0.3)
        
        // Border colors
        static let separator = Color(hex: "C6C6C8").opacity(0.2)
        static let border = Color(hex: "D1D1D6")
    }
    
    // MARK: - Typography
    struct Typography {
        // Headers
        static func largeTitle() -> Font { .system(size: 34, weight: .bold, design: .rounded) }
        static func title() -> Font { .system(size: 28, weight: .bold, design: .rounded) }
        static func title2() -> Font { .system(size: 22, weight: .semibold, design: .rounded) }
        static func title3() -> Font { .system(size: 20, weight: .semibold, design: .rounded) }
        
        // Body
        static func headline() -> Font { .system(size: 17, weight: .semibold, design: .default) }
        static func body() -> Font { .system(size: 17, weight: .regular, design: .default) }
        static func callout() -> Font { .system(size: 16, weight: .regular, design: .default) }
        static func subheadline() -> Font { .system(size: 15, weight: .regular, design: .default) }
        static func footnote() -> Font { .system(size: 13, weight: .regular, design: .default) }
        static func caption() -> Font { .system(size: 12, weight: .regular, design: .default) }
        static func caption2() -> Font { .system(size: 11, weight: .regular, design: .default) }
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
    }
    
    // MARK: - Radius
    struct Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 1000
    }
    
    // MARK: - Shadows
    struct Shadow {
        static func small() -> some View {
            Color.black.opacity(0.05)
                .blur(radius: 4)
                .offset(y: 2)
        }
        
        static func medium() -> some View {
            Color.black.opacity(0.08)
                .blur(radius: 8)
                .offset(y: 4)
        }
        
        static func large() -> some View {
            Color.black.opacity(0.12)
                .blur(radius: 16)
                .offset(y: 8)
        }
    }
}



// MARK: - Reusable Components
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                        .tint(.white)
                }
                Text(title)
                    .font(DesignSystem.Typography.headline())
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(isDisabled ? Color.gray : DesignSystem.Colors.primary)
            )
        }
        .disabled(isDisabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.headline())
                .foregroundColor(isDisabled ? .gray : DesignSystem.Colors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .stroke(isDisabled ? Color.gray : DesignSystem.Colors.primary, lineWidth: 2)
                )
        }
        .disabled(isDisabled)
    }
}

struct CardView<Content: View>: View {
    let content: Content
    var padding: CGFloat = DesignSystem.Spacing.md
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .fill(DesignSystem.Colors.secondaryBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text(title)
                .font(DesignSystem.Typography.headline())
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DesignSystem.Typography.caption())
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusBadge: View {
    enum Status {
        case success, warning, error, info, neutral
        
        var color: Color {
            switch self {
            case .success: return DesignSystem.Colors.success
            case .warning: return DesignSystem.Colors.warning
            case .error: return DesignSystem.Colors.danger
            case .info: return DesignSystem.Colors.info
            case .neutral: return DesignSystem.Colors.secondaryText
            }
        }
    }
    
    let text: String
    let status: Status
    
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption())
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.xs)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(
                Capsule()
                    .fill(status.color)
            )
    }
}