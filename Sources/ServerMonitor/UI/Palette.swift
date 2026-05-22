import SwiftUI

/// Tokyo Night-ish palette shared by the popover UI; matches the mockups
/// in TODO/overview.html and TODO/hover.html.
enum Palette {
    static let ok      = Color(red: 0x9e/255, green: 0xce/255, blue: 0x6a/255) // #9ece6a
    static let warn    = Color(red: 0xe0/255, green: 0xaf/255, blue: 0x68/255) // #e0af68
    static let danger  = Color(red: 0xf7/255, green: 0x76/255, blue: 0x8e/255) // #f7768e
    static let accent  = Color(red: 0x7a/255, green: 0xa2/255, blue: 0xf7/255) // #7aa2f7
    static let accent2 = Color(red: 0xbb/255, green: 0x9a/255, blue: 0xf7/255) // #bb9af7
    static let muted   = Color(red: 0x9a/255, green: 0xa3/255, blue: 0xb2/255) // #9aa3b2

    /// Threshold color for a 0–100 metric: <60 ok, <85 warn, else danger.
    static func threshold(_ pct: Double) -> Color {
        switch pct {
        case ..<60: return ok
        case ..<85: return warn
        default:    return danger
        }
    }
}
