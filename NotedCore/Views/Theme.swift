//  Theme.swift
//  A deliberately small token set (per the Codex design review) — spacing, one clinical accent with
//  a dark-mode variant, status colors, and radii. Not a design-system project; just enough to keep
//  the UI consistent and to read like a trustworthy instrument rather than a generic assistant.

import SwiftUI

enum Theme {
    // Spacing scale.
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s6: CGFloat = 24

    // Radii.
    static let badgeRadius: CGFloat = 6
    static let fieldRadius: CGFloat = 10

    // Row / control sizing.
    static let rowMinHeight: CGFloat = 56
    static let primaryControlHeight: CGFloat = 52

    /// One deep clinical teal, dark-mode aware — the app's single accent (not the default blue).
    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.32, green: 0.73, blue: 0.72, alpha: 1)
            : UIColor(red: 0.05, green: 0.42, blue: 0.44, alpha: 1)
    })

    static let recording = Color.red
    static let caution = Color.orange
    static let signed = Color.green

    static let hairline = Color(uiColor: .separator).opacity(0.55)
}
