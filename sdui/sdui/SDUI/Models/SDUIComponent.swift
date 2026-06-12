//
//  SDUIComponent.swift
//  sdui
//
//  The recursive component tree. An `indirect enum` with a custom decoder that
//  reads the `"type"` discriminator and decodes the matching props. Unknown types
//  decode to `.unknown` and render `EmptyView()` — forward compatibility: a new
//  server component never crashes an old client.
//

indirect enum SDUIComponent: Decodable {
    case vstack(ContainerProps)
    case hstack(ContainerProps)
    case zstack(ContainerProps)
    case spacer(SpacerProps)
    case text(TextProps)
    case image(ImageProps)
    case logo(LogoProps)
    case textField(TextFieldProps)
    case button(ButtonProps)
    case divider(DividerProps)
    case unknown

    private enum TypeKey: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
        let typed = try decoder.container(keyedBy: TypeKey.self)
        let type = try typed.decode(String.self, forKey: .type)

        // Leaf props and container props alike decode from the whole object.
        let single = decoder
        switch type {
        case "vstack": self = .vstack(try ContainerProps(from: single))
        case "hstack": self = .hstack(try ContainerProps(from: single))
        case "zstack": self = .zstack(try ContainerProps(from: single))
        case "spacer": self = .spacer(try SpacerProps(from: single))
        case "text": self = .text(try TextProps(from: single))
        case "image": self = .image(try ImageProps(from: single))
        case "logo": self = .logo(try LogoProps(from: single))
        case "textField": self = .textField(try TextFieldProps(from: single))
        case "button": self = .button(try ButtonProps(from: single))
        case "divider": self = .divider(try DividerProps(from: single))
        default: self = .unknown   // forward-compat catch-all — keep last, never throw
        }
    }
}
