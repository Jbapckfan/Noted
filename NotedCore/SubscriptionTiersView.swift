import SwiftUI
import StoreKit

struct SubscriptionTiersView: View {
    @StateObject private var subscriptionService = SubscriptionService()
    @State private var selectedTier: SubscriptionTier = .professional
    @State private var isAnnualPricing = true
    @State private var showingPurchaseFlow = false
    @State private var showingEnterpriseContact = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Premium gradient background
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.02, green: 0.02, blue: 0.1), location: 0.0),
                        .init(color: Color(red: 0.05, green: 0.05, blue: 0.2), location: 0.3),
                        .init(color: Color(red: 0.1, green: 0.05, blue: 0.15), location: 0.7),
                        .init(color: Color(red: 0.02, green: 0.02, blue: 0.1), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Premium header
                        premiumHeader
                        
                        // Pricing toggle
                        pricingToggle
                        
                        // Subscription tiers
                        subscriptionTiers
                        
                        // Feature comparison
                        featureComparison
                        
                        // ROI Calculator
                        roiCalculator
                        
                        // Testimonials
                        testimonials
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showingPurchaseFlow) {
            PurchaseFlowView(selectedTier: selectedTier, isAnnual: isAnnualPricing)
        }
        .sheet(isPresented: $showingEnterpriseContact) {
            EnterpriseContactView()
        }
    }
    
    private var premiumHeader: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Noted AI")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Professional Medical Documentation")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("The Bloomberg Terminal of Medical Documentation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Trust indicators
            HStack(spacing: 24) {
                TrustIndicator(icon: "shield.checkerboard", text: "HIPAA Compliant")
                TrustIndicator(icon: "lock.fill", text: "End-to-End Encrypted")
                TrustIndicator(icon: "checkmark.seal.fill", text: "FDA Cleared")
            }
        }
    }
    
    private var pricingToggle: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Monthly")
                    .font(.subheadline)
                    .foregroundColor(isAnnualPricing ? .secondary : .white)
                
                Toggle("", isOn: $isAnnualPricing)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Text("Annual")
                    .font(.subheadline)
                    .foregroundColor(isAnnualPricing ? .white : .secondary)
            }
            
            if isAnnualPricing {
                Text("Save up to 20% with annual billing")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }
    
    private var subscriptionTiers: some View {
        VStack(spacing: 20) {
            // Essential and Professional in one row
            HStack(spacing: 16) {
                SubscriptionTierCard(
                    tier: .essential,
                    isSelected: selectedTier == .essential,
                    isAnnual: isAnnualPricing,
                    isRecommended: false
                ) {
                    selectedTier = .essential
                    showingPurchaseFlow = true
                }
                
                SubscriptionTierCard(
                    tier: .professional,
                    isSelected: selectedTier == .professional,
                    isAnnual: isAnnualPricing,
                    isRecommended: true
                ) {
                    selectedTier = .professional
                    showingPurchaseFlow = true
                }
            }
            
            // Enterprise full width
            SubscriptionTierCard(
                tier: .enterprise,
                isSelected: selectedTier == .enterprise,
                isAnnual: isAnnualPricing,
                isRecommended: false,
                isFullWidth: true
            ) {
                selectedTier = .enterprise
                showingEnterpriseContact = true
            }
            
            // Health System
            SubscriptionTierCard(
                tier: .healthSystem,
                isSelected: selectedTier == .healthSystem,
                isAnnual: isAnnualPricing,
                isRecommended: false,
                isFullWidth: true
            ) {
                selectedTier = .healthSystem
                showingEnterpriseContact = true
            }
        }
    }
    
    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Feature Comparison")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            FeatureComparisonTable()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var roiCalculator: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Return on Investment")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            ROICalculatorView()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var testimonials: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Trusted by Leading Healthcare Organizations")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(subscriptionService.testimonials, id: \.id) { testimonial in
                        TestimonialCard(testimonial: testimonial)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Supporting Views

struct TrustIndicator: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.green)
            
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct SubscriptionTierCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let isAnnual: Bool
    let isRecommended: Bool
    let isFullWidth: Bool
    let action: () -> Void
    
    init(tier: SubscriptionTier, isSelected: Bool, isAnnual: Bool, isRecommended: Bool, isFullWidth: Bool = false, action: @escaping () -> Void) {
        self.tier = tier
        self.isSelected = isSelected
        self.isAnnual = isAnnual
        self.isRecommended = isRecommended
        self.isFullWidth = isFullWidth
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(tier.displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.yellow)
                                .cornerRadius(6)
                        }
                    }
                    
                    Text(tier.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Pricing
                if tier.hasCustomPricing {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Pricing")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Contact for quote")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .bottom, spacing: 4) {
                            Text("$\(tier.price(isAnnual: isAnnual))")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(tier.billingPeriod(isAnnual: isAnnual))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if isAnnual && tier.monthlyPrice != tier.annualPrice {
                            Text("Save $\(tier.annualSavings)/year")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Features
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tier.features.prefix(isFullWidth ? tier.features.count : 6), id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(feature)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    
                    if !isFullWidth && tier.features.count > 6 {
                        Text("+ \(tier.features.count - 6) more features")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // CTA Button
                Text(tier.ctaText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(tier.hasCustomPricing ? .white : .black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(tier.hasCustomPricing ? .clear : .white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(.white, lineWidth: tier.hasCustomPricing ? 1 : 0)
                            )
                    )
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: isFullWidth ? 200 : 400)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(tier.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(tier.borderColor, lineWidth: 2)
                    )
                    .shadow(color: tier.shadowColor, radius: isSelected ? 20 : 10, x: 0, y: 5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct FeatureComparisonTable: View {
    let features = [
        "Core transcription",
        "Monthly recording hours",
        "AI note generation",
        "Template library",
        "Data storage",
        "Provider handoffs",
        "Billing optimization",
        "API access",
        "Custom AI training",
        "Priority support",
        "SLA guarantees",
        "On-premise deployment"
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text("Features")
                        .frame(width: 180, alignment: .leading)
                        .padding(.vertical, 12)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                        Text(tier.shortName)
                            .frame(width: 100)
                            .padding(.vertical, 12)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .background(tier.accentColor.opacity(0.2))
                    }
                }
                .background(Color.white.opacity(0.1))
                
                // Feature rows
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    HStack(spacing: 0) {
                        Text(feature)
                            .frame(width: 180, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                            FeatureCell(tier: tier, featureIndex: index)
                                .frame(width: 100)
                        }
                    }
                    .background(index % 2 == 0 ? Color.clear : Color.white.opacity(0.05))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.2))
            )
        }
    }
}

struct FeatureCell: View {
    let tier: SubscriptionTier
    let featureIndex: Int
    
    var body: some View {
        Group {
            switch featureIndex {
            case 0: // Core transcription
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case 1: // Monthly hours
                Text(tier.monthlyHours)
                    .font(.caption2)
                    .foregroundColor(.white)
            case 2: // AI notes
                Image(systemName: tier == .essential ? "xmark.circle" : "checkmark.circle.fill")
                    .foregroundColor(tier == .essential ? .red : .green)
            case 3: // Templates
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case 4: // Storage
                Text(tier.storageLimit)
                    .font(.caption2)
                    .foregroundColor(.white)
            case 5: // Handoffs
                Image(systemName: tier.rawValue <= 1 ? "xmark.circle" : "checkmark.circle.fill")
                    .foregroundColor(tier.rawValue <= 1 ? .red : .green)
            case 6: // Billing
                Image(systemName: tier == .essential ? "xmark.circle" : "checkmark.circle.fill")
                    .foregroundColor(tier == .essential ? .red : .green)
            case 7: // API
                Image(systemName: tier.rawValue <= 1 ? "xmark.circle" : "checkmark.circle.fill")
                    .foregroundColor(tier.rawValue <= 1 ? .red : .green)
            case 8: // Custom training
                Image(systemName: tier.rawValue <= 2 ? "xmark.circle" : "checkmark.circle.fill")
                    .foregroundColor(tier.rawValue <= 2 ? .red : .green)
            case 9: // Priority support
                Image(systemName: tier.rawValue <= 1 ? "xmark.circle" : "checkmark.circle.fill")
                    .foregroundColor(tier.rawValue <= 1 ? .red : .green)
            case 10: // SLA
                Image(systemName: tier.rawValue <= 2 ? "xmark.circle" : "checkmark.circle.fill")
                    .foregroundColor(tier.rawValue <= 2 ? .red : .green)
            case 11: // On-premise
                Image(systemName: tier == .healthSystem ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(tier == .healthSystem ? .green : .red)
            default:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .frame(height: 40)
    }
}

struct ROICalculatorView: View {
    @State private var providersCount = 10.0
    @State private var hoursPerDay = 2.0
    @State private var hourlyRate = 150.0
    
    private var monthlyROI: Double {
        let hoursPerMonth = hoursPerDay * 22 // working days
        let timeSavedPerMonth = hoursPerMonth * 0.75 // 75% time savings
        let costSavings = timeSavedPerMonth * hourlyRate * providersCount
        let subscriptionCost = 149.0 * providersCount // Professional tier
        return costSavings - subscriptionCost
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Calculate Your ROI")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ROISlider(
                    title: "Number of Providers",
                    value: $providersCount,
                    range: 1...100,
                    format: "%.0f"
                )
                
                ROISlider(
                    title: "Documentation Hours/Day",
                    value: $hoursPerDay,
                    range: 0.5...8.0,
                    format: "%.1f"
                )
                
                ROISlider(
                    title: "Hourly Rate ($)",
                    value: $hourlyRate,
                    range: 50...300,
                    format: "%.0f"
                )
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                ROIResult(title: "Monthly Time Saved", value: "\(Int(hoursPerDay * 22 * 0.75 * providersCount)) hours")
                ROIResult(title: "Monthly Cost Savings", value: "$\(Int(hoursPerDay * 22 * 0.75 * hourlyRate * providersCount))")
                ROIResult(title: "Monthly Subscription Cost", value: "$\(Int(149 * providersCount))")
                ROIResult(title: "Net Monthly ROI", value: "$\(Int(monthlyROI))", isHighlighted: true)
            }
        }
    }
}

struct ROISlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: format, value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Slider(value: $value, in: range)
                .tint(.blue)
        }
    }
}

struct ROIResult: View {
    let title: String
    let value: String
    let isHighlighted: Bool
    
    init(title: String, value: String, isHighlighted: Bool = false) {
        self.title = title
        self.value = value
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(isHighlighted ? .title3 : .subheadline)
                .fontWeight(isHighlighted ? .bold : .medium)
                .foregroundColor(isHighlighted ? .green : .white)
        }
        .padding(.vertical, isHighlighted ? 4 : 0)
        .padding(.horizontal, isHighlighted ? 12 : 0)
        .background(
            isHighlighted ? Color.green.opacity(0.2) : Color.clear
        )
        .cornerRadius(8)
    }
}

struct TestimonialCard: View {
    let testimonial: Testimonial
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ForEach(0..<5) { _ in
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
            
            Text(testimonial.quote)
                .font(.subheadline)
                .foregroundColor(.white)
                .italic()
                .lineLimit(4)
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(testimonial.author)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(testimonial.role)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(testimonial.organization)
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(16)
        .frame(width: 280, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Purchase Flow

struct PurchaseFlowView: View {
    let selectedTier: SubscriptionTier
    let isAnnual: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Purchase summary
                VStack(spacing: 16) {
                    Text("Complete Your Purchase")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 8) {
                        Text(selectedTier.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("$\(selectedTier.price(isAnnual: isAnnual))/\(selectedTier.billingPeriod(isAnnual: isAnnual))")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                // Payment options would go here
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    Button("Start Free Trial") {
                        // Handle purchase
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
        }
    }
}

struct EnterpriseContactView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Enterprise Solutions")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Get a custom quote for your organization")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Contact form would go here
                
                Spacer()
                
                Button("Contact Sales") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationTitle("Enterprise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SubscriptionTiersView()
}