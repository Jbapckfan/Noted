import Foundation
import Combine
import StoreKit
import SwiftUI

@MainActor
class SubscriptionService: ObservableObject {
    @Published var currentTier: SubscriptionTier = .essential
    @Published var isSubscribed = false
    @Published var testimonials: [Testimonial] = []
    @Published var products: [Product] = []
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    init() {
        updateListenerTask = listenForTransactions()
        loadTestimonials()
        Task {
            await requestProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func requestProducts() async {
        do {
            // Request products from App Store
            let storeProducts = try await Product.products(for: SubscriptionTier.productIdentifiers)
            
            await MainActor.run {
                self.products = storeProducts
            }
        } catch {
            print("Failed to request products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
        case .userCancelled, .pending:
            break
        default:
            break
        }
    }
    
    
    @MainActor
    func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                
                if let tier = SubscriptionTier.fromProductIdentifier(transaction.productID) {
                    currentTier = tier
                    isSubscribed = true
                }
            } catch {
                print("Transaction failed verification")
            }
        }
    }
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func loadTestimonials() {
        testimonials = [
            Testimonial(
                id: "1",
                quote: "Noted AI has revolutionized our documentation workflow. We're saving 3 hours per day per provider and our accuracy has improved dramatically.",
                author: "Dr. Sarah Chen",
                role: "Chief Medical Officer",
                organization: "Stanford Health Care"
            ),
            Testimonial(
                id: "2",
                quote: "The AI-powered clinical decision support has caught several potential medication interactions. This technology is a game-changer for patient safety.",
                author: "Dr. Michael Rodriguez",
                role: "Emergency Department Director",
                organization: "Mayo Clinic"
            ),
            Testimonial(
                id: "3",
                quote: "Implementation was seamless and the ROI was evident within the first month. Our providers love the intuitive interface and accurate transcriptions.",
                author: "Jennifer Walsh",
                role: "VP of Clinical Operations",
                organization: "Kaiser Permanente"
            ),
            Testimonial(
                id: "4",
                quote: "The enterprise collaboration features have transformed our handoff processes. Critical information is never lost between provider transitions.",
                author: "Dr. David Kim",
                role: "Hospitalist Program Director",
                organization: "Cleveland Clinic"
            ),
            Testimonial(
                id: "5",
                quote: "Noted AI's billing optimization has increased our revenue capture by 15%. The compliance features give us complete confidence in our documentation.",
                author: "Lisa Thompson",
                role: "Chief Revenue Officer",
                organization: "Johns Hopkins Medicine"
            )
        ]
    }
}

// MARK: - Data Models

enum SubscriptionTier: Int, CaseIterable {
    case essential = 0
    case professional = 1
    case enterprise = 2
    case healthSystem = 3
    
    var displayName: String {
        switch self {
        case .essential: return "Noted Essential"
        case .professional: return "Noted Professional"
        case .enterprise: return "Noted Enterprise"
        case .healthSystem: return "Noted Health System"
        }
    }
    
    var shortName: String {
        switch self {
        case .essential: return "Essential"
        case .professional: return "Professional"
        case .enterprise: return "Enterprise"
        case .healthSystem: return "Health System"
        }
    }
    
    var description: String {
        switch self {
        case .essential: return "Perfect for individual practitioners starting with AI-powered documentation"
        case .professional: return "Advanced features for established practitioners and small practices"
        case .enterprise: return "Complete solution for large practices and departments"
        case .healthSystem: return "Unlimited scalability for hospital systems and health networks"
        }
    }
    
    var monthlyPrice: Int {
        switch self {
        case .essential: return 49
        case .professional: return 149
        case .enterprise: return 499
        case .healthSystem: return 0 // Custom pricing
        }
    }
    
    var annualPrice: Int {
        switch self {
        case .essential: return 39
        case .professional: return 119
        case .enterprise: return 399
        case .healthSystem: return 0 // Custom pricing
        }
    }
    
    var annualSavings: Int {
        return (monthlyPrice * 12) - (annualPrice * 12)
    }
    
    func price(isAnnual: Bool) -> Int {
        return isAnnual ? annualPrice : monthlyPrice
    }
    
    func billingPeriod(isAnnual: Bool) -> String {
        return isAnnual ? "month" : "month"
    }
    
    var hasCustomPricing: Bool {
        return self == .healthSystem
    }
    
    var ctaText: String {
        switch self {
        case .essential, .professional: return "Start Free Trial"
        case .enterprise, .healthSystem: return "Contact Sales"
        }
    }
    
    var features: [String] {
        switch self {
        case .essential:
            return [
                "Core transcription features",
                "100 hours monthly recording",
                "Basic note templates",
                "30-day data storage",
                "Email support",
                "HIPAA compliance",
                "Mobile app access",
                "Basic audio processing"
            ]
        case .professional:
            return [
                "Unlimited transcription",
                "Advanced AI note generation",
                "Custom templates library",
                "1-year data storage",
                "Billing optimization",
                "API access",
                "Priority support",
                "Advanced audio processing",
                "Clinical decision support",
                "Real-time collaboration",
                "Specialty-specific models",
                "Quality metrics dashboard"
            ]
        case .enterprise:
            return [
                "Everything in Professional",
                "Department analytics",
                "Provider handoff tools",
                "Custom AI training",
                "Unlimited data storage",
                "Dedicated account manager",
                "SLA guarantees",
                "Advanced security controls",
                "Audit trail reporting",
                "Custom integrations",
                "White-label options",
                "24/7 phone support"
            ]
        case .healthSystem:
            return [
                "Everything in Enterprise",
                "Unlimited providers",
                "On-premise deployment",
                "Custom data sovereignty",
                "Dedicated infrastructure",
                "Custom training programs",
                "Advanced analytics suite",
                "Multi-site management",
                "Custom compliance reporting",
                "Dedicated success team",
                "Custom SLA terms",
                "Executive reporting"
            ]
        }
    }
    
    var monthlyHours: String {
        switch self {
        case .essential: return "100"
        case .professional, .enterprise, .healthSystem: return "Unlimited"
        }
    }
    
    var storageLimit: String {
        switch self {
        case .essential: return "30 days"
        case .professional: return "1 year"
        case .enterprise, .healthSystem: return "Unlimited"
        }
    }
    
    var backgroundColor: LinearGradient {
        switch self {
        case .essential:
            return LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .professional:
            return LinearGradient(
                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .enterprise:
            return LinearGradient(
                colors: [Color.orange.opacity(0.2), Color.red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .healthSystem:
            return LinearGradient(
                colors: [Color.green.opacity(0.2), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var borderColor: Color {
        switch self {
        case .essential: return .blue.opacity(0.3)
        case .professional: return .purple.opacity(0.5)
        case .enterprise: return .orange.opacity(0.5)
        case .healthSystem: return .green.opacity(0.5)
        }
    }
    
    var shadowColor: Color {
        switch self {
        case .essential: return .blue.opacity(0.2)
        case .professional: return .purple.opacity(0.3)
        case .enterprise: return .orange.opacity(0.3)
        case .healthSystem: return .green.opacity(0.3)
        }
    }
    
    var accentColor: Color {
        switch self {
        case .essential: return .blue
        case .professional: return .purple
        case .enterprise: return .orange
        case .healthSystem: return .green
        }
    }
    
    var productIdentifier: String {
        switch self {
        case .essential: return "com.noted.essential.monthly"
        case .professional: return "com.noted.professional.monthly"
        case .enterprise: return "com.noted.enterprise.monthly"
        case .healthSystem: return "com.noted.healthsystem.custom"
        }
    }
    
    static var productIdentifiers: [String] {
        return SubscriptionTier.allCases.map { $0.productIdentifier }
    }
    
    static func fromProductIdentifier(_ identifier: String) -> SubscriptionTier? {
        return SubscriptionTier.allCases.first { $0.productIdentifier == identifier }
    }
}

struct Testimonial: Identifiable {
    let id: String
    let quote: String
    let author: String
    let role: String
    let organization: String
}

enum StoreError: Error {
    case failedVerification
}