//
//  SDUIProps.swift
//  sdui
//
//  One `…Props` struct per component kind. Props reuse the style tokens in
//  SDUIStyle.swift — never invent new color/size encodings here. Container props
//  carry their `children`, which decode recursively through SDUIComponent.
//

import CoreGraphics

struct ContainerProps: Decodable {
    var children: [SDUIComponent] = []
    var spacing: CGFloat?
    var horizontalAlignment: SDUIHorizontalAlignment?
    var verticalAlignment: SDUIVerticalAlignment?
    var padding: SDUIPadding?
    var background: SDUIColor?
    var cornerRadius: CGFloat?
    var fillWidth: Bool?
}

struct SpacerProps: Decodable {
    var minLength: CGFloat?
}

struct TextProps: Decodable {
    var text: String
    var style: SDUIFontStyle?
    var weight: SDUIFontWeight?
    var color: SDUIColor?
    var alignment: SDUIHorizontalAlignment?
    var interpolatesFields: Bool?
}

struct ImageProps: Decodable {
    var systemName: String
    var size: CGFloat?
    var color: SDUIColor?
    var renderingMode: String?     // "multicolor"
}

struct LogoProps: Decodable {
    var text: String
    var foreground: SDUIColor?
    var background: SDUIColor?
    var size: CGFloat?
}

struct TextFieldProps: Decodable {
    var fieldId: String
    var placeholder: String?
    var keyboardType: String?      // phonePad | numberPad | emailAddress | decimalPad | default
    var leading: SDUIComponent?
    var trailingIcon: String?
}

struct ButtonProps: Decodable {
    var title: String
    var style: String?             // primary | secondary | link
    var leadingIcon: String?
    var iconRenderingMode: String?
    var action: SDUIAction?
}

struct DividerProps: Decodable {
    var label: String?
    var color: SDUIColor?
}
