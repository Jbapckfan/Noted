import Foundation

struct AIModelConfiguration {
    static let shared = AIModelConfiguration()

    // Model settings
    let modelPath = "Models/phi-3-mini.mlx"
    let maxTokens = 2048
    let temperature = 0.7

    // Chart settings
    let rvuRate: Double = 35.0 // $ per RVU
    let sessionLimit = 10

    // Feature flags
    let enableChartStrength = true
    let enableProcedureDetection = true
    let enableRealtimeValidation = true

    // Prompt settings
    let includeExamples = true
    let exampleCount = 3
}