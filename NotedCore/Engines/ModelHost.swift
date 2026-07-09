//  ModelHost.swift
//  Shared, observable state for the on-device model download/load, so the UI can show progress on
//  first launch (the 4-bit model is ~1.8 GB and downloads once, then is cached).

import Foundation

@MainActor
@Observable
public final class ModelHost {
    public static let shared = ModelHost()

    public enum State: Equatable {
        case idle
        case downloading(Double)   // 0…1
        case ready
        case failed(String)
    }

    public var state: State = .idle

    public var isReady: Bool { state == .ready }

    /// Short line for a status banner, or nil when ready/idle.
    public var banner: String? {
        switch state {
        case .idle:                    return "Preparing on-device AI…"
        case .downloading(let p):      return "Downloading on-device AI model… \(Int(p * 100))%"
        case .failed(let why):         return "AI model unavailable — \(why). Recording still transcribes."
        case .ready:                   return nil
        }
    }

    func update(_ new: State) { state = new }
}
