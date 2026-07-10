//  ModelHost.swift
//  Shared, observable state for loading the on-device model, so the UI can show a status line on
//  first launch. In the offline build the ~1.8 GB 4-bit model ships IN the app bundle — it is
//  loaded from disk, never downloaded — so there is no network progress to report.

import Foundation

@MainActor
@Observable
public final class ModelHost {
    public static let shared = ModelHost()

    public enum State: Equatable {
        case idle
        case loadingModel          // reading the bundled model into memory (no network)
        case downloading(Double)   // legacy/source-compat only — an offline build never downloads
        case ready
        case failed(String)
    }

    public var state: State = .idle

    public var isReady: Bool { state == .ready }

    /// Short line for a status banner, or nil when ready/idle.
    public var banner: String? {
        switch state {
        case .idle:                    return "Preparing on-device AI…"
        case .loadingModel:            return "Loading on-device AI model…"
        case .downloading(let p):      return "Loading on-device AI model… \(Int(p * 100))%"
        case .failed(let why):         return "AI model unavailable — \(why). Recording still transcribes."
        case .ready:                   return nil
        }
    }

    func update(_ new: State) { state = new }
}
