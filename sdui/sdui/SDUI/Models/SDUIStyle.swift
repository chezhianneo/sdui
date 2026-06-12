//
//  SDUIStyle.swift
//  sdui
//
//  Style tokens shared by every SDUI component: colors, fonts, alignment, padding.
//  Tokens decode from JSON and resolve to SwiftUI values at render time. Unknown
//  tokens never crash — they fall back to sensible defaults (colors → .clear).
//

import SwiftUI
import UIKit

// MARK: - Color

/// A color token. Accepts a hex string ("#RRGGBB", "#RGB", "#RRGGBBAA") or a
/// semantic name (label, secondaryLabel, white, black, clear, background,
/// secondaryBackground, tint). Unknown names resolve to `.clear`.
struct SDUIColor: Decodable {
    let raw: String

    init(_ raw: String) { self.raw = raw }

    init(from decoder: Decoder) throws {
        raw = try decoder.singleValueContainer().decode(String.self)
    }

    var color: Color {
        if raw.hasPrefix("#") { return Self.hex(raw) ?? .clear }
        switch raw.lowercased() {
        case "label": return .primary
        case "secondarylabel": return .secondary
        case "white": return .white
        case "black": return .black
        case "clear": return .clear
        case "background": return Color(UIColor.systemBackground)
        case "secondarybackground": return Color(UIColor.secondarySystemBackground)
        case "tint": return .accentColor
        default: return .clear
        }
    }

    private static func hex(_ string: String) -> Color? {
        var s = String(string.dropFirst())
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }   // expand #RGB
        guard let value = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        switch s.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1
        case 8:
            r = Double((value & 0xFF000000) >> 24) / 255
            g = Double((value & 0x00FF0000) >> 16) / 255
            b = Double((value & 0x0000FF00) >> 8) / 255
            a = Double(value & 0x000000FF) / 255
        default:
            return nil
        }
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Font

enum SDUIFontStyle: String, Decodable {
    case largeTitle, title, title2, title3, headline, subheadline, body, callout, footnote, caption

    var font: Font {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption
        }
    }
}

enum SDUIFontWeight: String, Decodable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

    var weight: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

// MARK: - Alignment

enum SDUIHorizontalAlignment: String, Decodable {
    case leading, center, trailing

    var alignment: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

enum SDUIVerticalAlignment: String, Decodable {
    case top, center, bottom

    var alignment: VerticalAlignment {
        switch self {
        case .top: .top
        case .center: .center
        case .bottom: .bottom
        }
    }
}

// MARK: - Padding

/// Decodes from a single number (applied to all edges) or an object with any of
/// `top, leading, bottom, trailing, horizontal, vertical, all`.
struct SDUIPadding: Decodable {
    var top: CGFloat = 0
    var leading: CGFloat = 0
    var bottom: CGFloat = 0
    var trailing: CGFloat = 0

    private enum CodingKeys: String, CodingKey {
        case top, leading, bottom, trailing, horizontal, vertical, all
    }

    init(from decoder: Decoder) throws {
        if let scalar = try? decoder.singleValueContainer().decode(CGFloat.self) {
            top = scalar; leading = scalar; bottom = scalar; trailing = scalar
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let all = try c.decodeIfPresent(CGFloat.self, forKey: .all)
        let h = try c.decodeIfPresent(CGFloat.self, forKey: .horizontal)
        let v = try c.decodeIfPresent(CGFloat.self, forKey: .vertical)
        top = try c.decodeIfPresent(CGFloat.self, forKey: .top) ?? v ?? all ?? 0
        bottom = try c.decodeIfPresent(CGFloat.self, forKey: .bottom) ?? v ?? all ?? 0
        leading = try c.decodeIfPresent(CGFloat.self, forKey: .leading) ?? h ?? all ?? 0
        trailing = try c.decodeIfPresent(CGFloat.self, forKey: .trailing) ?? h ?? all ?? 0
    }

    var edgeInsets: EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
}
