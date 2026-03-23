import SwiftUI

// MARK: - Design Tokens (source: TOKENS.md)

enum Tokens {

    enum Color {
        static let background   = SwiftUI.Color(hex: "0B0F14")
        static let surface      = SwiftUI.Color(hex: "121821")
        static let panel        = SwiftUI.Color(hex: "1A222D")
        static let textPrimary  = SwiftUI.Color(hex: "E6EDF3")
        static let textSecondary = SwiftUI.Color(hex: "9DA7B3")
        static let accent       = SwiftUI.Color(hex: "3ABEFF")
        static let success      = SwiftUI.Color(hex: "2ECC71")
        static let warning      = SwiftUI.Color(hex: "F5A623")
        static let error        = SwiftUI.Color(hex: "E5533D")
    }

    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum Radius {
        static let small:  CGFloat = 6
        static let medium: CGFloat = 10
    }

    enum Motion {
        static let micro:  Double = 0.12
        static let normal: Double = 0.22
        static let modal:  Double = 0.28
    }
}

// MARK: - Color hex initialiser

extension SwiftUI.Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
